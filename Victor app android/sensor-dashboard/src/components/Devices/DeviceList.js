import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../../lib/supabaseClient';
import { 
  Box, Typography, CircularProgress, Alert,
  Table, TableBody, TableCell, TableContainer, TableHead, TableRow, 
  Paper, Chip, Button
} from '@mui/material';

export default function DeviceList() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [devices, setDevices] = useState([]);
  
  useEffect(() => {
    async function fetchDevices() {
      try {
        setLoading(true);
        setError(null);
        
        const { data, error } = await supabase
          .from('devices')
          .select('*')
          .order('last_active', { ascending: false });
          
        if (error) throw error;
        setDevices(data || []);
        
      } catch (error) {
        console.error('Erro ao buscar dispositivos:', error);
        setError(error.message);
      } finally {
        setLoading(false);
      }
    }
    
    fetchDevices();
  }, []);
  
  // Formato de data para exibição
  const formatDate = (dateString) => {
    if (!dateString) return 'Nunca';
    return new Date(dateString).toLocaleString();
  };
  
  // Status do dispositivo baseado na última atividade
  const getDeviceStatus = (lastActive) => {
    if (!lastActive) return { label: 'Inativo', color: 'error' };
    
    const lastActiveDate = new Date(lastActive);
    const now = new Date();
    const diffMinutes = (now - lastActiveDate) / (1000 * 60);
    
    if (diffMinutes < 5) return { label: 'Online', color: 'success' };
    if (diffMinutes < 60) return { label: 'Recente', color: 'warning' };
    return { label: 'Offline', color: 'error' };
  };
  
  if (loading) return <CircularProgress />;
  
  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        Dispositivos
      </Typography>
      
      {error && <Alert severity="error" sx={{ mb: 3 }}>{error}</Alert>}
      
      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>ID</TableCell>
              <TableCell>Nome</TableCell>
              <TableCell>Modo</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Última Atividade</TableCell>
              <TableCell>Ações</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {devices.map((device) => {
              const status = getDeviceStatus(device.last_active);
              
              return (
                <TableRow key={device.id}>
                  <TableCell>{device.id.substring(0, 8)}...</TableCell>
                  <TableCell>{device.name}</TableCell>
                  <TableCell>
                    <Chip 
                      label={device.operation_mode || 'continuous'} 
                      color={device.operation_mode === 'impact' ? 'secondary' : 'primary'}
                      size="small"
                    />
                  </TableCell>
                  <TableCell>
                    <Chip 
                      label={status.label} 
                      color={status.color}
                      size="small"
                    />
                  </TableCell>
                  <TableCell>{formatDate(device.last_active)}</TableCell>
                  <TableCell>
                    <Button 
                      variant="outlined" 
                      size="small"
                      component={Link}
                      to={`/devices/${device.id}`}
                    >
                      Detalhes
                    </Button>
                  </TableCell>
                </TableRow>
              );
            })}
            
            {devices.length === 0 && (
              <TableRow>
                <TableCell colSpan={6} align="center">
                  Nenhum dispositivo encontrado
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}