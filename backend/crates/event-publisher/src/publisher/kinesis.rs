use aws_sdk_kinesis::Client;
use serde::Serialize;
use serde_json::to_vec;
use tokio::sync::mpsc;
use tokio::time::{sleep, Duration, Instant};
use tracing::{error, info, warn, debug};

#[derive(Clone)]
pub struct KinesisPublisher {
    sender: mpsc::Sender<PublishRequest>,
}

#[derive(Debug)]
pub struct PublishRequest {
    pub partition_key: String,
    pub payload: Vec<u8>,
}

struct CircuitBreaker {
    failure_count: u32,
    failure_threshold: u32,
    reset_timeout: Duration,
    last_failure_time: Option<Instant>,
    state: CircuitState,
}

#[derive(PartialEq)]
enum CircuitState {
    Closed, // Flow normally
    Open,   // Drop requests immediately
    HalfOpen, // Allow one request to test the waters
}

impl CircuitBreaker {
    fn new(threshold: u32, timeout: Duration) -> Self {
        Self {
            failure_count: 0,
            failure_threshold: threshold,
            reset_timeout: timeout,
            last_failure_time: None,
            state: CircuitState::Closed,
        }
    }

    fn check_state(&mut self) -> CircuitState {
        if self.state == CircuitState::Open {
            if let Some(last_fail) = self.last_failure_time {
                if last_fail.elapsed() >= self.reset_timeout {
                    self.state = CircuitState::HalfOpen;
                    return CircuitState::HalfOpen;
                }
            }
        }
        
        if self.state == CircuitState::Closed {
            CircuitState::Closed
        } else {
            CircuitState::Open
        }
    }

    fn record_success(&mut self) {
        self.failure_count = 0;
        self.last_failure_time = None;
        self.state = CircuitState::Closed;
    }

    fn record_failure(&mut self) {
        self.failure_count += 1;
        self.last_failure_time = Some(Instant::now());
        if self.failure_count >= self.failure_threshold {
            if self.state != CircuitState::Open {
                warn!("CircuitBreaker is now OPEN! Too many Kinesis failures.");
            }
            self.state = CircuitState::Open;
        }
    }
}

impl KinesisPublisher {
    /// Initialize the Kinesis Publisher with an asynchronous, decoupled worker task.
    pub async fn new(stream_name: String) -> Self {
        let config = aws_config::load_defaults(aws_config::BehaviorVersion::latest()).await;
        let client = Client::new(&config);

        // Decoupling & Concurrency: 
        // We use an MPSC channel with a bounded capacity (10k items) to prevent OOM.
        let (sender, mut receiver) = mpsc::channel::<PublishRequest>(10000);

        tokio::spawn(async move {
            info!("Starting Kinesis background publisher worker for stream '{}'", stream_name);
            
            // Circuit Breaker: Open after 5 continuous failures, wait 30 seconds before testing again.
            let mut cb = CircuitBreaker::new(5, Duration::from_secs(30));

            while let Some(request) = receiver.recv().await {
                
                let state = cb.check_state();
                if state == CircuitState::Open {
                    // Circuit is open, drop the event immediately to clear the backlog and not stall.
                    warn!("Circuit OPEN - Dropping event '{}' to protect memory and avoid stalling.", request.partition_key);
                    continue;
                }

                // Retry Mechanism with Exponential Backoff
                let mut retries = 0;
                let max_retries = 3;
                let mut success = false;

                loop {
                    match client
                        .put_record()
                        .stream_name(&stream_name)
                        .partition_key(&request.partition_key)
                        .data(aws_sdk_kinesis::primitives::Blob::new(request.payload.clone()))
                        .send()
                        .await
                    {
                        Ok(res) => {
                            debug!(
                                "Successfully published event to Kinesis. Shard: {:?}, Seq: {:?}",
                                res.shard_id(),
                                res.sequence_number()
                            );
                            success = true;
                            break; // Exit retry loop
                        }
                        Err(e) => {
                            retries += 1;
                            if retries > max_retries {
                                error!(
                                    "Failed to publish to Kinesis after {} retries. Error: {:?}", 
                                    max_retries, 
                                    e
                                );
                                break;
                            }
                            warn!("Kinesis publish attempt {} failed: {:?}. Retrying...", retries, e);
                            sleep(Duration::from_millis(200 * (1 << retries))).await; // 400ms, 800ms...
                        }
                    }
                }

                if success {
                    cb.record_success();
                } else {
                    cb.record_failure();
                }
            }
            info!("Kinesis publisher background task shutting down");
        });

        Self { sender }
    }

    /// Non-blocking publish method. 
    /// Enqueues the event into the channel without blocking the calling thread.
    /// Event struct T should already contain unique identifiers (UUID) for idempotency downstream.
    pub fn publish_event<T: Serialize>(&self, partition_key: String, event: &T) {
        match to_vec(event) {
            Ok(payload) => {
                let sender = self.sender.clone();
                let request = PublishRequest {
                    partition_key,
                    payload,
                };
                
                // Spawn a tiny task to send to channel. 
                // We use `.send().await` to ensure we handle backpressure without blocking 
                // the synchronous thread, though `try_send` could also be used to intentionally drop on full load.
                tokio::spawn(async move {
                    if let Err(e) = sender.send(request).await {
                        error!("Channel closed/failed to enqueue event for Kinesis publishing: {:?}", e);
                    }
                });
            }
            Err(e) => {
                error!("Failed to serialize event for Kinesis: {:?}", e);
            }
        }
    }
}
