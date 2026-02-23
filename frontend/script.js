const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');
const coordsEl = document.getElementById('coords');
const pingEl = document.getElementById('ping');
const elementEl = document.getElementById('active-element');

// Game State
let player = {
    x: window.innerWidth / 2,
    y: window.innerHeight / 2,
    size: 20,
    speed: 5,
    element: 'Anemo',
    color: '#00ffcc'
};

const elements = {
    '1': { name: 'Anemo', color: '#00ffcc' },
    '2': { name: 'Pyro', color: '#ff4d4d' },
    '3': { name: 'Electro', color: '#cc33ff' },
    '4': { name: 'Hydro', color: '#3399ff' }
};

let keys = {};

// Resize canvas
function resize() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
}
window.addEventListener('resize', resize);
resize();

// Input listeners
window.addEventListener('keydown', (e) => {
    keys[e.key.toLowerCase()] = true;
    
    // Switch character/element
    if (elements[e.key]) {
        switchCharacter(e.key);
    }
});

window.addEventListener('keyup', (e) => {
    keys[e.key.toLowerCase()] = false;
});

function switchCharacter(id) {
    player.element = elements[id].name;
    player.color = elements[id].color;
    elementEl.textContent = player.element;
    
    // Update UI
    document.querySelectorAll('.char').forEach(el => el.classList.remove('active'));
    document.getElementById(`char${id}`).classList.add('active');
    
    console.log(`Switched to ${player.element}`);
    sendTelemetry('character_swap', { element: player.element });
}

function update() {
    if (keys['w'] || keys['arrowup']) player.y -= player.speed;
    if (keys['s'] || keys['arrowdown']) player.y += player.speed;
    if (keys['a'] || keys['arrowleft']) player.x -= player.speed;
    if (keys['d'] || keys['arrowright']) player.x += player.speed;
    
    // Constraints
    player.x = Math.max(player.size, Math.min(canvas.width - player.size, player.x));
    player.y = Math.max(player.size, Math.min(canvas.height - player.size, player.y));
    
    coordsEl.textContent = `(${Math.round(player.x)}, ${Math.round(player.y)})`;
}

function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Draw grid
    ctx.strokeStyle = '#333';
    ctx.lineWidth = 1;
    for (let i = 0; i < canvas.width; i += 50) {
        ctx.beginPath(); ctx.moveTo(i, 0); ctx.lineTo(i, canvas.height); ctx.stroke();
    }
    for (let i = 0; i < canvas.height; i += 50) {
        ctx.beginPath(); ctx.moveTo(0, i); ctx.lineTo(canvas.width, i); ctx.stroke();
    }
    
    // Draw Player
    ctx.fillStyle = player.color;
    ctx.shadowBlur = 15;
    ctx.shadowColor = player.color;
    ctx.beginPath();
    ctx.arc(player.x, player.y, player.size, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;
}

function loop() {
    update();
    draw();
    requestAnimationFrame(loop);
}

// Telemetry Simulation
function sendTelemetry(event, data) {
    const startTime = Date.now();
    // In a real scenario, this would be a fetch to our Rust backend with a region header
    // fetch('/api/telemetry', { method: 'POST', body: JSON.stringify({...}) })
    
    // Simulate RTT calculation
    const simulatedRTT = Math.floor(Math.random() * 50) + 10; 
    pingEl.textContent = simulatedRTT;
}

// Start game
loop();

// Periodic sync telemetry
setInterval(() => {
    sendTelemetry('position_sync', { x: player.x, y: player.y });
}, 1000);
