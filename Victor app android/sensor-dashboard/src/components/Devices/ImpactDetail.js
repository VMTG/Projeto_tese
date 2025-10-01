import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '../../lib/supabaseClient';
import { 
  Box, Typography, CircularProgress, Alert, Grid, Card, CardContent,
  Button, Chip, Divider, List, ListItem, ListItemText, Paper, 
  Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
  IconButton
} from '@mui/material';
import { ArrowBack } from '@mui/icons-material';
import { Line } from 'react-chartjs-2';

export default function ImpactDetail() {
  const { impactId } = useParams();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [impact, setImpact] = useState(null);
  const [impactDetails, setImpactDetails] = useState(null);
  const [deviceInfo, setDeviceInfo] = useState(null);
  const [timeSeriesData, setTimeSeriesData] = useState([]);

  // Buscar dados do impacto e detalhes relacionados
  useEffect(() => {
    async function fetchImpactData() {
      try {
        setLoading(true);
        setError(null);
        
        // Buscar informações do impacto
        const { data: impactData, error: impactError } = await supabase
          .from('impact_events')
          .select('*')
          .eq('id', impactId)
          .single();
          
        if (impactError) throw impactError;
        setImpact(impactData);
        
        // Buscar detalhes do impacto (HIC, BRIC, etc.)
        const { data: detailsData, error: detailsError } = await supabase
          .from('impact_details')
          .select('*')
          .eq('impact_event_id', impactId)
          .single();
          
        if (!detailsError) {
          setImpactDetails(detailsData);
        }
        
        // Buscar informações do dispositivo
        if (impactData.device_id) {
          const { data: deviceData, error: deviceError } = await supabase
            .from('devices')
            .select('*')
            .eq('id', impactData.device_id)
            .single();
            
          if (!deviceError) {
            setDeviceInfo(deviceData);
          }
        }
        
        // Buscar dados de série temporal (se disponíveis)
        const { data: seriesData, error: seriesError } = await supabase
          .from('impact_time_series')
          .select('*')
          .eq('impact_event_id', impactId)
          .order('timestamp', { ascending: true });
          
        if (!seriesError && seriesData) {
          setTimeSeriesData(seriesData);
        }
        
      } catch (error) {
        console.error('Erro ao buscar dados do impacto:', error);
        setError(error.message);
      } finally {
        setLoading(false);
      }
    }
    
    if (impactId) {
      fetchImpactData();
    }
  }, [impactId]);

  // Preparar dados para o gráfico de aceleração
  const getAccelerationChartData = () => {
    // Se temos dados de série temporal, usar esses
    if (timeSeriesData && timeSeriesData.length > 0) {
      return {
        labels: timeSeriesData.map(item => 
          new Date(item.timestamp).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit', second:'2-digit', fractionalSecondDigits: 3})
        ),
        datasets: [
          {
            label: 'Aceleração Total (g)',
            data: timeSeriesData.map(item => item.accel_total),
            borderColor: 'rgb(54, 162, 235)',
            backgroundColor: 'rgba(54, 162, 235, 0.5)',
            borderWidth: 2,
            tension: 0.1,
          },
        ],
      };
    }
    
    // Caso contrário, usar um único ponto dos dados de impacto
    return {
      labels: [new Date(impact?.timestamp).toLocaleTimeString()],
      datasets: [
        {
          label: 'Aceleração Total (g)',
          data: [impact?.accel_total || impact?.intensity],
          borderColor: 'rgb(54, 162, 235)',
          backgroundColor: 'rgba(54, 162, 235, 0.5)',
          borderWidth: 2,
          pointRadius: 5,
        },
      ],
    };
  };
  
  // Opções para gráficos
  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'top',
      },
      title: {
        display: true,
        text: 'Perfil de Aceleração do Impacto',
      },
      annotation: {
        annotations: {
          thresholdLine: {
            type: 'line',
            yMin: 5.0,
            yMax: 5.0,
            borderColor: 'rgba(255, 99, 132, 0.5)',
            borderWidth: 2,
            label: {
              content: 'Threshold (5.0g)',
              enabled: true
            }
          }
        }
      }
    },
    scales: {
      x: {
        title: {
          display: true,
          text: 'Tempo',
        },
      },
      y: {
        title: {
          display: true,
          text: 'Aceleração (g)',
        },
      },
    },
  };

  if (loading) return (
    <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '50vh' }}>
      <CircularProgress />
    </Box>
  );
  
  if (error) return <Alert severity="error">{error}</Alert>;
  if (!impact) return <Alert severity="warning">Evento de impacto não encontrado</Alert>;
  
  // Formatar timestamp para exibição
  const formattedTimestamp = new Date(impact.timestamp).toLocaleString();
  
  // Determinar a cor do chip de severidade
  const getSeverityColor = (severity) => {
    if (!severity) return 'default';
    if (severity.includes('Alto')) return 'error';
    if (severity.includes('Moderado')) return 'warning';
    return 'success';
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
        <IconButton onClick={() => navigate(-1)} sx={{ mr: 1 }}>
          <ArrowBack />
        </IconButton>
        <Typography variant="h4" component="h1">
          Detalhes do Impacto
        </Typography>
      </Box>
      
      <Grid container spacing={3}>
        {/* Informações Básicas */}
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Informações Básicas
              </Typography>
              <Divider sx={{ mb: 2 }} />
              
              <List disablePadding>
                <ListItem>
                  <ListItemText primary="Data/Hora" secondary={formattedTimestamp} />
                </ListItem>
                <ListItem>
                  <ListItemText 
                    primary="Dispositivo" 
                    secondary={deviceInfo?.name || impact.device_id} 
                  />
                </ListItem>
                <ListItem>
                  <ListItemText 
                    primary="Intensidade" 
                    secondary={`${impact.intensity.toFixed(2)} g`} 
                  />
                </ListItem>
                <ListItem>
                  <ListItemText 
                    primary="Significativo" 
                    secondary={
                      <Chip 
                        label={impact.significant ? 'Sim' : 'Não'} 
                        color={impact.significant ? 'error' : 'default'}
                        size="small"
                      />
                    } 
                  />
                </ListItem>
                {impactDetails?.impact_severity && (
                  <ListItem>
                    <ListItemText 
                      primary="Classificação" 
                      secondary={
                        <Chip 
                          label={impactDetails.impact_severity} 
                          color={getSeverityColor(impactDetails.impact_severity)}
                          size="small"
                        />
                      } 
                    />
                  </ListItem>
                )}
              </List>
            </CardContent>
          </Card>
        </Grid>
        
        {/* Métricas de Impacto */}
        <Grid item xs={12} md={8}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Métricas de Impacto
              </Typography>
              <Divider sx={{ mb: 2 }} />
              
              <Grid container spacing={2}>
                <Grid item xs={12} md={6}>
                  <Card variant="outlined">
                    <CardContent>
                      <Typography variant="subtitle1" color="text.secondary" gutterBottom>
                        HIC (Head Injury Criterion)
                      </Typography>
                      <Typography variant="h4">
                        {impactDetails?.hic_value ? impactDetails.hic_value.toFixed(2) : 'N/A'}
                      </Typography>
                      <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                        Valores de referência:<br />
                        &lt;250: Baixo risco<br />
                        250-1000: Risco moderado<br />
                        &gt;1000: Alto risco
                      </Typography>
                    </CardContent>
                  </Card>
                </Grid>
                
                <Grid item xs={12} md={6}>
                  <Card variant="outlined">
                    <CardContent>
                      <Typography variant="subtitle1" color="text.secondary" gutterBottom>
                        BRIC (Brain Injury Criterion)
                      </Typography>
                      <Typography variant="h4">
                        {impactDetails?.bric_value ? impactDetails.bric_value.toFixed(2) : 'N/A'}
                      </Typography>
                      <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                        Valores de referência:<br />
                        &lt;1.0: Baixo risco<br />
                        1.0-2.0: Risco moderado<br />
                        &gt;2.0: Alto risco
                      </Typography>
                    </CardContent>
                  </Card>
                </Grid>
              </Grid>
            </CardContent>
          </Card>
        </Grid>
        
        {/* Gráfico de Aceleração */}
        <Grid item xs={12}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Perfil de Aceleração
              </Typography>
              <Divider sx={{ mb: 2 }} />
              
              <Box sx={{ height: 400 }}>
                <Line 
                  data={getAccelerationChartData()} 
                  options={chartOptions}
                />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        
        {/* Dados Completos do Sensor */}
        <Grid item xs={12}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Dados do Sensor no Momento do Impacto
              </Typography>
              <Divider sx={{ mb: 2 }} />
              
              <Grid container spacing={3}>
                <Grid item xs={12} md={6}>
                  <Typography variant="subtitle2" gutterBottom>
                    Aceleração
                  </Typography>
                  <TableContainer component={Paper} variant="outlined">
                    <Table size="small">
                      <TableHead>
                        <TableRow>
                          <TableCell>Eixo</TableCell>
                          <TableCell align="right">Valor (g)</TableCell>
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        <TableRow>
                          <TableCell>X</TableCell>
                          <TableCell align="right">{impact.accel_x?.toFixed(2) || 'N/A'}</TableCell>
                        </TableRow>
                        <TableRow>
                          <TableCell>Y</TableCell>
                          <TableCell align="right">{impact.accel_y?.toFixed(2) || 'N/A'}</TableCell>
                        </TableRow>
                        <TableRow>
                          <TableCell>Z</TableCell>
                          <TableCell align="right">{impact.accel_z?.toFixed(2) || 'N/A'}</TableCell>
                        </TableRow>
                        <TableRow>
                          <TableCell sx={{ fontWeight: 'bold' }}>Total</TableCell>
                          <TableCell align="right" sx={{ fontWeight: 'bold' }}>
                            {(impact.accel_total || impact.intensity).toFixed(2)}
                          </TableCell>
                        </TableRow>
                      </TableBody>
                    </Table>
                  </TableContainer>
                </Grid>
                
                <Grid item xs={12} md={6}>
                  <Typography variant="subtitle2" gutterBottom>
                    Rotação
                  </Typography>
                  <TableContainer component={Paper} variant="outlined">
                    <Table size="small">
                      <TableHead>
                        <TableRow>
                          <TableCell>Eixo</TableCell>
                          <TableCell align="right">Valor (°/s)</TableCell>
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        <TableRow>
                          <TableCell>X</TableCell>
                          <TableCell align="right">{impact.gyro_x?.toFixed(2) || 'N/A'}</TableCell>
                        </TableRow>
                        <TableRow>
                          <TableCell>Y</TableCell>
                          <TableCell align="right">{impact.gyro_y?.toFixed(2) || 'N/A'}</TableCell>
                        </TableRow>
                        <TableRow>
                          <TableCell>Z</TableCell>
                          <TableCell align="right">{impact.gyro_z?.toFixed(2) || 'N/A'}</TableCell>
                        </TableRow>
                        <TableRow>
                          <TableCell sx={{ fontWeight: 'bold' }}>Total</TableCell>
                          <TableCell align="right" sx={{ fontWeight: 'bold' }}>
                            {impact.gyro_total?.toFixed(2) || 'N/A'}
                          </TableCell>
                        </TableRow>
                      </TableBody>
                    </Table>
                  </TableContainer>
                </Grid>
              </Grid>
            </CardContent>
          </Card>
        </Grid>
        
        {/* Botão de Voltar */}
        <Grid item xs={12} sx={{ display: 'flex', justifyContent: 'center', mt: 2 }}>
          <Button 
            variant="contained" 
            startIcon={<ArrowBack />}
            onClick={() => navigate(-1)}
          >
            Voltar para o Dispositivo
          </Button>
        </Grid>
      </Grid>
    </Box>
  );
}