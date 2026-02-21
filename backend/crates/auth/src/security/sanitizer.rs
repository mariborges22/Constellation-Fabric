pub fn sanitize_input(input: &str) -> Result<String, String> {
    if input.contains("DROP TABLE") { return Err("Invalid input".to_string()); }
    Ok(input.to_string())
}
