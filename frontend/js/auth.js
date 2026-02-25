// ============================================================================
// Auth Service - Frontend Integration (Remote)
// ============================================================================

const AUTH_API = 'http://constellation-fabric-us-east-1-a-2070272044.us-east-1.elb.amazonaws.com/api/auth';
const TOKEN_KEY = 'constellation_token';

class AuthService {
  static async register(username, email, password) {
    try {
      const response = await fetch(${AUTH_API}/register, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, email, password }),
      });
      
      if (!response.ok) throw new Error(Registration failed: \);
      
      const data = await response.json();
      this.setToken(data.token);
      return data;
    } catch (error) {
      console.error('Registration error:', error);
      throw error;
    }
  }

  static async login(username, password) {
    try {
      const response = await fetch(${AUTH_API}/login, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      });
      
      if (!response.ok) throw new Error(Login failed: \);
      
      const data = await response.json();
      this.setToken(data.token);
      return data;
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  }

  static getToken() { return localStorage.getItem(TOKEN_KEY); }
  static setToken(token) { localStorage.setItem(TOKEN_KEY, token); }
  static logout() { localStorage.removeItem(TOKEN_KEY); }
  static isAuthenticated() { return this.getToken() !== null; }

  static getAuthHeaders() {
    const token = this.getToken();
    if (!token) return { 'Content-Type': 'application/json' };
    return {
      'Authorization': Bearer \,
      'Content-Type': 'application/json',
    };
  }

  static async verify() {
    try {
      const response = await fetch(${AUTH_API}/verify, {
        method: 'POST',
        headers: this.getAuthHeaders(),
        body: JSON.stringify({ token: this.getToken() })
      });
      return response.ok;
    } catch (error) {
      return false;
    }
  }
}
