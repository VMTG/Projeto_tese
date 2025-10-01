import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '../../lib/supabaseClient';
import { 
    Box, Typography, CircularProgress, Alert, Grid, Card, CardContent,
    Tabs, Tab, Button, Chip, Select, MenuItem, FormControl, InputLabel,
    Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper
  } from '@mui/material';
import { Line } from 'react-chartjs-2';

export default function DeviceDetail() {
  const { deviceId } = useParams();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [device, setDevice] = useState(null);
  const [sensorData, setSensorData] = useState({});
  const [tabValue, setTabValue] = useState(0);
  const [timeRange, setTimeRange] = useState('1h');
  
  // Buscar dados do dispositivo
  useEffect(() => {
    async function fetchDeviceData() {
      try {
        setLoading(true);
        setError(null);
        
        // Buscar informações do dispositivo
        const { data, error } = await supabase
          .from('devices')
          .select('*')
          .eq('id', deviceId)
          .single();
          
        if (error) throw error;
        setDevice(data);
        
      } catch (error) {
        console.error('Erro ao buscar dados do dispositivo:', error);
        setError(error.message);
      } finally {
        setLoading(false);
      }
    }
    
    if (deviceId) {
      fetchDeviceData();
    }
  }, [deviceId]);
  
  // Buscar dados do sensor com base no intervalo de tempo
  useEffect(() => {
    async function fetchSensorData() {
      if (!deviceId) return;
      
      try {
        setLoading(true);
        
        // Calcular timestamp com base no intervalo selecionado
        const now = new Date();
        let timestamp;
        
        switch (timeRange) {
          case '1h':
            timestamp = new Date(now.getTime() - 60 * 60 * 1000).toISOString();
            break;
          case '12h':
            timestamp = new Date(now.getTime() - 12 * 60 * 60 * 1000).toISOString();
            break;
          case '24h':
            timestamp = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
            break;
          case '7d':
            timestamp = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
            break;
          default:
            timestamp = new Date(now.getTime() - 60 * 60 * 1000).toISOString();
        }
        
        // Buscar diferentes tipos de dados do sensor
        const dataTypes = [
          'temperature', 'pressure', 
          'accelTotal', 'accelX', 'accelY', 'accelZ', 
          'gyroTotal', 'gyroX', 'gyroY', 'gyroZ'
        ];
        const result = {};
        
        for (const type of dataTypes) {
          const { data, error } = await supabase
            .from('processed_sensor_data')
            .select('*')
            .eq('device_id', deviceId)
            .eq('data_type', type)
            .gte('timestamp', timestamp)
            .order('timestamp', { ascending: true });
            
          if (error) throw error;
          result[type] = data || [];
        }
        
        setSensorData(result);
        
      } catch (error) {
        console.error('Erro ao buscar dados do sensor:', error);
        setError(error.message);
      } finally {
        setLoading(false);
      }
    }
    
    fetchSensorData();
  }, [deviceId, timeRange]);
  
  // Preparar dados para o gráfico de temperatura
  const getChartData = (dataType, label, color) => {
    const data = sensorData[dataType] || [];


    return {
      labels: data.map(item => new Date(item.timestamp).toLocaleTimeString()),
      datasets: [
        {
          label: label,
          data: data.map(item => item.value),
          borderColor: color,
          backgroundColor: color.replace('rgb', 'rgba').replace(')', ', 0.5)'),
          borderWidth: 2,
          pointRadius: 0,
          tension: 0.1,
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
          text: 'Valor',
        },
      },
    },
  };
  
  if (loading && !device) return <CircularProgress />;
  if (error) return <Alert severity="error">{error}</Alert>;
  if (!device) return <Alert severity="warning">Dispositivo não encontrado</Alert>;
  
  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
        <Typography variant="h4" component="h1">
          Dispositivo: {device.name}
        </Typography>
        
        <Box>
          <Chip 
            label={device.operation_mode || 'continuous'} 
            color={device.operation_mode === 'impact' ? 'secondary' : 'primary'}
            sx={{ mr: 1 }}
          />
          
          <FormControl sx={{ minWidth: 120 }}>
            <InputLabel>Período</InputLabel>
            <Select
              value={timeRange}
              label="Período"
              onChange={(e) => setTimeRange(e.target.value)}
              size="small"
            >
              <MenuItem value="1h">Última hora</MenuItem>
              <MenuItem value="12h">Últimas 12 horas</MenuItem>
              <MenuItem value="24h">Últimas 24 horas</MenuItem>
              <MenuItem value="7d">Últimos 7 dias</MenuItem>
            </Select>
          </FormControl>
        </Box>
      </Box>
      
      <Tabs 
        value={tabValue} 
        onChange={(e, newValue) => setTabValue(newValue)}
        sx={{ mb: 3 }}
      >
        <Tab label="Visão Geral" />
        <Tab label="Aceleração" />
        <Tab label="Rotação" />
        <Tab label="Eventos de Impacto" />
      </Tabs>
      
      {/* Visão Geral */}
      {tabValue === 0 && (
        <Grid container spacing={3}>
          <Grid item xs={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Aceleração Total
                </Typography>
                <Box sx={{ height: 300 }}>
                  <Line 
                    data={getChartData('accelTotal', 'Aceleração (g)', 'rgb(54, 162, 235)')} 
                    options={chartOptions}
                  />
                </Box>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Rotação Total
                </Typography>
                <Box sx={{ height: 300 }}>
                  <Line 
                    data={getChartData('gyroTotal', 'Rotação (dps)', 'rgb(153, 102, 255)')} 
                    options={chartOptions}
                  />
                </Box>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
        
      )}
          
      {/* Aceleração */}
      {tabValue === 1 && (
        <Grid container spacing={3}>
          <Grid item xs={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Aceleração Total
                </Typography>
                <Box sx={{ height: 300 }}>
                  <Line 
                    data={getChartData('accelTotal', 'Aceleração Total (g)', 'rgb(54, 162, 235)')} 
                    options={{
                      ...chartOptions,
                      plugins: {
                        ...chartOptions.plugins,
                        annotation: {
                          annotations: {
                            line1: {
                              type: 'line',
                              yMin: 5.0,
                              yMax: 5.0,
                              borderColor: 'rgb(255, 99, 132)',
                              borderWidth: 2,
                              label: {
                                content: 'Threshold',
                                enabled: true
                              }
                            }
                          }
                        }
                      }
                    }}
                  />
                </Box>
              </CardContent>
            </Card>
          </Grid>
          
          <Grid item xs={12} md={4}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Aceleração X
                </Typography>
                <Box sx={{ height: 250 }}>
                  <Line 
                    data={getChartData('accelX', 'Aceleração X (g)', 'rgb(255, 99, 132)')} 
                    options={chartOptions}
                  />
                </Box>
              </CardContent>
            </Card>
          </Grid>
          
          <Grid item xs={12} md={4}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Aceleração Y
                </Typography>
                <Box sx={{ height: 250 }}>
                  <Line 
                    data={getChartData('accelY', 'Aceleração Y (g)', 'rgb(54, 162, 235)')} 
                    options={chartOptions}
                  />
                </Box>
              </CardContent>
            </Card>
          </Grid>
          
          <Grid item xs={12} md={4}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Aceleração Z
                </Typography>
                <Box sx={{ height: 250 }}>
                  <Line 
                    data={getChartData('accelZ', 'Aceleração Z (g)', 'rgb(75, 192, 192)')} 
                    options={chartOptions}
                  />
                </Box>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      )}
          
      {/* Giroscópio */}
      {tabValue === 2 && (
        <Grid container spacing={3}>
          <Grid item xs={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Rotação Total
                </Typography>
                <Box sx={{ height: 300 }}>
                  <Line 
                    data={getChartData('gyroTotal', 'Rotação (dps)', 'rgb(153, 102, 255)')} 
                    options={chartOptions}
                  />
                </Box>
              </CardContent>
            </Card>
          </Grid>
          
          <Grid item xs={12} md={4}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Rotação X
                </Typography>
                <Box sx={{ height: 250 }}>
                  <Line 
                    data={getChartData('gyroX', 'Rotação X (dps)', 'rgb(255, 159, 64)')} 
                    options={chartOptions}
                  />
                </Box>
              </CardContent>
            </Card>
          </Grid>
          
          <Grid item xs={12} md={4}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                Rotação Y
                </Typography>
                <Box sx={{ height: 250 }}>
                  <Line 
                    data={getChartData('gyroY', 'Rotação Y (dps)', 'rgb(255, 205, 86)')} 
                    options={chartOptions}
                  />
                </Box>
              </CardContent>
            </Card>
          </Grid>
          
          <Grid item xs={12} md={4}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                Rotação Z
                </Typography>
                <Box sx={{ height: 250 }}>
                  <Line 
                    data={getChartData('gyroZ', 'Rotação Z (dps)', 'rgb(201, 203, 207)')} 
                    options={chartOptions}
                  />
                </Box>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      )}
        
      {/* Eventos de Impacto */}
      {tabValue === 3 && (
        <ImpactEventsList deviceId={deviceId} />
      )}
    </Box>
  );
}

    // Componente de lista de eventos de impacto
    function ImpactEventsList({ deviceId }) {
      const [loading, setLoading] = useState(true);
      const [error, setError] = useState(null);
      const [impactEvents, setImpactEvents] = useState([]);
      const navigate = useNavigate();
      
      useEffect(() => {
        async function fetchImpactEvents() {
          try {
            setLoading(true);
            
            const { data, error } = await supabase
              .from('impact_events')
              .select(`
                *,
                impact_details(*)
              `)
              .eq('device_id', deviceId)
              .order('timestamp', { ascending: false })
              .limit(50);
              
            if (error) throw error;
            setImpactEvents(data || []);
            
          } catch (error) {
            console.error('Erro ao buscar eventos de impacto:', error);
            setError(error.message);
          } finally {
            setLoading(false);
          }
        }
        
        fetchImpactEvents();
      }, [deviceId]);
      
      if (loading) return <CircularProgress />;
      if (error) return <Alert severity="error">{error}</Alert>;
      
      return (
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              Eventos de Impacto Recentes
            </Typography>
            
            <TableContainer component={Paper}>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Data/Hora</TableCell>
                    <TableCell>Intensidade</TableCell>
                    <TableCell>Significativo</TableCell>
                    <TableCell>Ações</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {impactEvents.map((event) => (
                    <TableRow key={event.id}>
                      <TableCell>
                        {new Date(event.timestamp).toLocaleString()}
                      </TableCell>
                      <TableCell>
                        {event.intensity.toFixed(2)} g
                      </TableCell>
                      <TableCell>
                        <Chip 
                          label={event.significant ? 'Sim' : 'Não'} 
                          color={event.significant ? 'error' : 'default'}
                          size="small"
                        />
                      </TableCell>
                      <TableCell>
                        <Button 
                          variant="outlined" 
                          size="small"
                          onClick={() => navigate(`/devices/impact/${event.id}`)}
                        >
                          Detalhes
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                  
                  {impactEvents.length === 0 && (
                    <TableRow>
                      <TableCell colSpan={4} align="center">
                        Nenhum evento de impacto encontrado
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            </TableContainer>
          </CardContent>
        </Card>
      );
    }
