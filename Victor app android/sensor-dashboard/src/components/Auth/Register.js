import { useState } from 'react';
import { supabase } from '../../lib/supabaseClient';
import { Box, TextField, Button, Typography, Alert } from '@mui/material';

export default function Register() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(false);

  const handleRegister = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSuccess(false);
    
    try {
      const { error } = await supabase.auth.signUp({
        email,
        password,
      });
      
      if (error) throw error;
      setSuccess(true);
    } catch (error) {
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box 
      component="form" 
      onSubmit={handleRegister} 
      sx={{ 
        maxWidth: 400, 
        mx: 'auto', 
        mt: 8, 
        p: 3, 
        border: '1px solid #ddd', 
        borderRadius: 2 
      }}
    >
      <Typography variant="h5" component="h1" gutterBottom>
        Criar Conta
      </Typography>
      
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
      {success && (
        <Alert severity="success" sx={{ mb: 2 }}>
          Registro bem-sucedido! Verifique seu email para confirmar sua conta.
        </Alert>
      )}
      
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
      
      <Button 
        type="submit" 
        variant="contained" 
        fullWidth 
        sx={{ mt: 3 }}
        disabled={loading}
      >
        {loading ? 'Registando...' : 'Registar'}
      </Button>
    </Box>
  );
}