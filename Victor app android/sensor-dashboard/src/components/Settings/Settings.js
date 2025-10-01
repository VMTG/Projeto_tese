import { useState } from 'react';
import { 
  Box, Typography, Card, CardContent, TextField, 
  Button, Alert, Divider, Switch, FormControlLabel
} from '@mui/material';

export default function Settings() {
  const [saving, setSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [impactThreshold, setImpactThreshold] = useState(5.0);
  const [emailNotifications, setEmailNotifications] = useState(true);
  const [dataRetentionDays, setDataRetentionDays] = useState(30);
  
  const handleSaveSettings = async () => {
    setSaving(true);
    setSaveSuccess(false);
    
    // Simulação de salvamento no backend
    setTimeout(() => {
      setSaving(false);
      setSaveSuccess(true);
      
      // Limpar mensagem de sucesso após alguns segundos
      setTimeout(() => setSaveSuccess(false), 3000);
    }, 1000);
  };
  
  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        Configurações
      </Typography>
      
      {saveSuccess && (
        <Alert severity="success" sx={{ mb: 3 }}>
          Configurações salvas com sucesso!
        </Alert>
      )}
      
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Configurações de Sensor
          </Typography>
          
          <Box sx={{ mb: 3 }}>
            <TextField
              label="Limite de Impacto (g)"
              type="number"
              value={impactThreshold}
              onChange={(e) => setImpactThreshold(parseFloat(e.target.value))}
              fullWidth
              margin="normal"
              InputProps={{
                inputProps: { min: 1, max: 20, step: 0.1 }
              }}
              helperText="Valor mínimo de aceleração para detectar um impacto"
            />
          </Box>
          
          <Divider sx={{ my: 2 }} />
          
          <Typography variant="h6" gutterBottom>
            Notificações
          </Typography>
          
          <Box sx={{ mb: 3 }}>
            <FormControlLabel
              control={
                <Switch
                  checked={emailNotifications}
                  onChange={(e) => setEmailNotifications(e.target.checked)}
                />
              }
              label="Notificações por email"
            />
            <Typography variant="body2" color="text.secondary">
              Receba alertas por email quando ocorrerem impactos significativos
            </Typography>
          </Box>
          
          <Divider sx={{ my: 2 }} />
          
          <Typography variant="h6" gutterBottom>
            Armazenamento de Dados
          </Typography>
          
          <Box sx={{ mb: 3 }}>
            <TextField
              label="Retenção de Dados (dias)"
              type="number"
              value={dataRetentionDays}
              onChange={(e) => setDataRetentionDays(parseInt(e.target.value))}
              fullWidth
              margin="normal"
              InputProps={{
                inputProps: { min: 1, max: 365, step: 1 }
              }}
              helperText="Período de armazenamento dos dados brutos"
            />
          </Box>
          
          <Button
            variant="contained"
            onClick={handleSaveSettings}
            disabled={saving}
          >
            {saving ? 'Salvando...' : 'Salvar Configurações'}
          </Button>
        </CardContent>
      </Card>
    </Box>
  );
}