import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../../lib/supabaseClient';
import { 
  Box, TextField, Button, Typography, Alert, 
  FormControlLabel, Checkbox, Divider
} from '@mui/material';

export default function Login() {
  const [isRegister, setIsRegister] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [rememberMe, setRememberMe] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const navigate = useNavigate();

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    
    try {
      const { error } = await supabase.auth.signInWithPassword({
        email,
        password
      });
      
      if (error) throw error;
      
      navigate('/dashboard');
    } catch (error) {
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleRegister = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSuccess(null);
    
    // Verificar se as senhas coincidem
    if (password !== confirmPassword) {
      setError("As senhas não coincidem");
      setLoading(false);
      return;
    }
    
    try {
      const { error } = await supabase.auth.signUp({
        email,
        password,
      });
      
      if (error) throw error;
      
      setSuccess("Conta criada com sucesso! Verifique seu email para confirmar seu cadastro.");
      // Limpar os campos do formulário
      setEmail('');
      setPassword('');
      setConfirmPassword('');
      // Voltar para o modo de login
      setIsRegister(false);
    } catch (error) {
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };

  const toggleMode = () => {
    setIsRegister(!isRegister);
    setError(null);
    setSuccess(null);
  };

  return (
    <Box sx={{ maxWidth: 400, mx: 'auto', mt: 8, p: 3, border: '1px solid #ddd', borderRadius: 2 }}>
      <Typography variant="h5" component="h1" gutterBottom>
        {isRegister ? 'Criar Conta' : 'Login'}
      </Typography>
      
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
      {success && <Alert severity="success" sx={{ mb: 2 }}>{success}</Alert>}
      
      <Box component="form" onSubmit={isRegister ? handleRegister : handleLogin}>
        <TextField
          label="Email"
          type="email"
          fullWidth
          margin="normal"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        
        <TextField
          label="Senha"
          type="password"
          fullWidth
          margin="normal"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />
        
        {isRegister && (
          <TextField
            label="Confirmar Senha"
            type="password"
            fullWidth
            margin="normal"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            required
          />
        )}
        
        {!isRegister && (
          <FormControlLabel
            control={
              <Checkbox
                checked={rememberMe}
                onChange={(e) => setRememberMe(e.target.checked)}
                color="primary"
              />
            }
            label="Lembrar-me"
          />
        )}
        
        <Button 
          type="submit" 
          variant="contained" 
          fullWidth 
          sx={{ mt: 3 }}
          disabled={loading}
        >
          {loading 
            ? (isRegister ? 'Registrando...' : 'Entrando...') 
            : (isRegister ? 'Criar Conta' : 'Entrar')}
        </Button>
      </Box>
      
      <Divider sx={{ my: 3 }} />
      
      <Box sx={{ textAlign: 'center' }}>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
          {isRegister 
            ? 'Já tem uma conta?' 
            : 'Ainda não tem uma conta?'}
        </Typography>
        
        <Button 
          onClick={toggleMode}
          variant="outlined"
          fullWidth
        >
          {isRegister ? 'Fazer Login' : 'Criar Conta'}
        </Button>
      </Box>
    </Box>
  );
}