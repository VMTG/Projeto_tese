import { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabaseClient';
import { 
  Box, Typography, Paper, Grid, Card, CardContent,
  Table, TableBody, TableCell, TableContainer, TableHead, TableRow, TablePagination,
  Chip, CircularProgress, Alert, Button, TextField, MenuItem, IconButton,
  Dialog, DialogActions, DialogContent, DialogTitle
} from '@mui/material';
import InfoIcon from '@mui/icons-material/Info';
import FilterListIcon from '@mui/icons-material/FilterList';
import DownloadIcon from '@mui/icons-material/Download';
import { Line } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
} from 'chart.js';

// Registrar componentes ChartJS
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
);

export default function ImpactAnalysis() {
  // Estados para controle de dados e UI
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [impacts, setImpacts] = useState([]);
  const [devices, setDevices] = useState([]);
  const [totalCount, setTotalCount] = useState(0);
  
  // Estados para filtros e paginação
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const [filters, setFilters] = useState({
    deviceId: '',
    minIntensity: '',
    maxIntensity: '',
    significant: '',
    startDate: '',
    endDate: '',
  });
  const [showFilters, setShowFilters] = useState(false);
  
  // Estado para diálogo de detalhes
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [selectedImpact, setSelectedImpact] = useState(null);
  const [impactDetail, setImpactDetail] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);

  useEffect(() => {
    // Buscar dispositivos para usar nos filtros
    async function fetchDevices() {
      try {
        const { data, error } = await supabase
          .from('devices')
          .select('id, name');
          
        if (error) throw error;
        setDevices(data || []);
      } catch (err) {
        console.error('Erro ao buscar dispositivos:', err);
      }
    }
    
    fetchDevices();
  }, []);

  useEffect(() => {
    // Buscar dados de impactos com filtros e paginação
    async function fetchImpacts() {
      try {
        setLoading(true);
        setError(null);
        
        // Construir query com filtros
        let query = supabase
          .from('impact_events')
          .select(`
            *,
            devices(name),
            impact_details(*)
          `, { count: 'exact' });
        
        // Aplicar filtros
        if (filters.deviceId) {
          query = query.eq('device_id', filters.deviceId);
        }
        
        if (filters.minIntensity) {
          query = query.gte('intensity', parseFloat(filters.minIntensity));
        }
        
        if (filters.maxIntensity) {
          query = query.lte('intensity', parseFloat(filters.maxIntensity));
        }
        
        if (filters.significant === 'true') {
          query = query.eq('significant', true);
        } else if (filters.significant === 'false') {
          query = query.eq('significant', false);
        }
        
        if (filters.startDate) {
          query = query.gte('timestamp', filters.startDate);
        }
        
        if (filters.endDate) {
          query = query.lte('timestamp', filters.endDate);
        }
        
        // Aplicar ordenação, paginação e executar
        const { data, error, count } = await query
          .order('timestamp', { ascending: false })
          .range(page * rowsPerPage, (page * rowsPerPage) + rowsPerPage - 1);
          
        if (error) throw error;
        
        setImpacts(data || []);
        setTotalCount(count || 0);
      } catch (err) {
        console.error('Erro ao buscar impactos:', err);
        setError(err.message);
      } finally {
        setLoading(false);
      }
    }
    
    fetchImpacts();
  }, [page, rowsPerPage, filters]);

  // Função para buscar detalhes de um impacto específico
  const fetchImpactDetails = async (impact) => {
    try {
      setDetailLoading(true);
      setSelectedImpact(impact);
      
      // Buscar detalhes do impacto
      const { data: details, error: detailsError } = await supabase
        .from('impact_details')
        .select('*',)
        .eq('impact_event_id', impact.id)
        .single();
        
      if (detailsError && detailsError.code !== 'PGRST116') {
        throw detailsError;
      }
      
      // Buscar dados brutos do sensor para este impacto
      const startTime = new Date(impact.timestamp);
      const endTime = new Date(startTime);
      endTime.setSeconds(startTime.getSeconds() + 10); // 10 segundos após o impacto
      
      const { data: sensorData, error: sensorError } = await supabase
        .from('raw_sensor_data')
        .select('*')
        .eq('device_id', impact.device_id)
        .gte('timestamp', startTime.toISOString())
        .lte('timestamp', endTime.toISOString())
        .order('timestamp');
        
      if (sensorError) throw sensorError;
      
      setImpactDetail({
        details: details || null,
        sensorData: sensorData || []
      });
      
      setDetailsOpen(true);
    } catch (err) {
      console.error('Erro ao buscar detalhes do impacto:', err);
      alert('Erro ao buscar detalhes do impacto: ' + err.message);
    } finally {
      setDetailLoading(false);
    }
  };

  // Handlers para mudanças de paginação
  const handleChangePage = (event, newPage) => {
    setPage(newPage);
  };

  const handleChangeRowsPerPage = (event) => {
    setRowsPerPage(parseInt(event.target.value, 10));
    setPage(0);
  };

  // Handler para mudanças nos filtros
  const handleFilterChange = (event) => {
    const { name, value } = event.target;
    setFilters(prev => ({
      ...prev,
      [name]: value
    }));
  };

  // Handler para limpar filtros
  const handleClearFilters = () => {
    setFilters({
      deviceId: '',
      minIntensity: '',
      maxIntensity: '',
      significant: '',
      startDate: '',
      endDate: '',
    });
    setPage(0);
  };

  // Fechar modal de detalhes
  const handleCloseDetails = () => {
    setDetailsOpen(false);
  };

  // Preparar dados para gráfico caso haja um impacto selecionado
  const chartData = impactDetail && impactDetail.sensorData.length > 0 ? {
    labels: impactDetail.sensorData.map(d => new Date(d.timestamp).toLocaleTimeString()),
    datasets: [
      {
        label: 'Aceleração Total',
        data: impactDetail.sensorData.map(d => d.accel_total),
        borderColor: 'rgb(255, 99, 132)',
        backgroundColor: 'rgba(255, 99, 132, 0.5)',
      },
      {
        label: 'Aceleração X',
        data: impactDetail.sensorData.map(d => d.accel_x),
        borderColor: 'rgb(53, 162, 235)',
        backgroundColor: 'rgba(53, 162, 235, 0.5)',
        hidden: true,
      },
      {
        label: 'Aceleração Y',
        data: impactDetail.sensorData.map(d => d.accel_y),
        borderColor: 'rgb(75, 192, 192)',
        backgroundColor: 'rgba(75, 192, 192, 0.5)',
        hidden: true,
      },
      {
        label: 'Aceleração Z',
        data: impactDetail.sensorData.map(d => d.accel_z),
        borderColor: 'rgb(255, 159, 64)',
        backgroundColor: 'rgba(255, 159, 64, 0.5)',
        hidden: true,
      },
    ],
  } : null;

  // Função para exportar dados
  const handleExportCsv = () => {
    // Implementar exportação de dados para CSV
    alert('Funcionalidade de exportação a ser implementada');
  };

  // Função para determinar cor do chip de severidade
  const getSeverityColor = (severity) => {
    if (!severity) return 'default';
    switch (severity.toLowerCase()) {
      case 'alta':
      case 'high':
        return 'error';
      case 'média':
      case 'medium':
        return 'warning';
      case 'baixa':
      case 'low':
        return 'success';
      default:
        return 'default';
    }
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4" component="h1" gutterBottom>
          Análise de Impactos
        </Typography>
        
        <Box>
          <Button 
            variant="outlined" 
            startIcon={<FilterListIcon />} 
            onClick={() => setShowFilters(!showFilters)}
            sx={{ mr: 1 }}
          >
            {showFilters ? 'Ocultar Filtros' : 'Mostrar Filtros'}
          </Button>
          
          <Button
            variant="contained"
            startIcon={<DownloadIcon />}
            onClick={handleExportCsv}
          >
            Exportar
          </Button>
        </Box>
      </Box>
      
      {error && <Alert severity="error" sx={{ mb: 3 }}>{error}</Alert>}
      
      {/* Painel de Filtros */}
      {showFilters && (
        <Paper sx={{ p: 2, mb: 3 }}>
          <Typography variant="h6" gutterBottom>Filtros</Typography>
          
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6} md={4} lg={2}>
              <TextField
                select
                fullWidth
                label="Dispositivo"
                name="deviceId"
                value={filters.deviceId}
                onChange={handleFilterChange}
                variant="outlined"
                size="small"
              >
                <MenuItem value="">Todos</MenuItem>
                {devices.map((device) => (
                  <MenuItem key={device.id} value={device.id}>
                    {device.name}
                  </MenuItem>
                ))}
              </TextField>
            </Grid>
            
            <Grid item xs={12} sm={6} md={4} lg={2}>
              <TextField
                fullWidth
                label="Intensidade Min."
                name="minIntensity"
                type="number"
                value={filters.minIntensity}
                onChange={handleFilterChange}
                variant="outlined"
                size="small"
              />
            </Grid>
            
            <Grid item xs={12} sm={6} md={4} lg={2}>
              <TextField
                fullWidth
                label="Intensidade Max."
                name="maxIntensity"
                type="number"
                value={filters.maxIntensity}
                onChange={handleFilterChange}
                variant="outlined"
                size="small"
              />
            </Grid>
            
            <Grid item xs={12} sm={6} md={4} lg={2}>
              <TextField
                select
                fullWidth
                label="Significativo"
                name="significant"
                value={filters.significant}
                onChange={handleFilterChange}
                variant="outlined"
                size="small"
              >
                <MenuItem value="">Todos</MenuItem>
                <MenuItem value="true">Sim</MenuItem>
                <MenuItem value="false">Não</MenuItem>
              </TextField>
            </Grid>
            
            <Grid item xs={12} sm={6} md={4} lg={2}>
              <TextField
                fullWidth
                label="Data Inicial"
                name="startDate"
                type="datetime-local"
                InputLabelProps={{ shrink: true }}
                value={filters.startDate}
                onChange={handleFilterChange}
                variant="outlined"
                size="small"
              />
            </Grid>
            
            <Grid item xs={12} sm={6} md={4} lg={2}>
              <TextField
                fullWidth
                label="Data Final"
                name="endDate"
                type="datetime-local"
                InputLabelProps={{ shrink: true }}
                value={filters.endDate}
                onChange={handleFilterChange}
                variant="outlined"
                size="small"
              />
            </Grid>
          </Grid>
          
          <Box sx={{ mt: 2, textAlign: 'right' }}>
            <Button
              variant="outlined"
              onClick={handleClearFilters}
              sx={{ mr: 1 }}
            >
              Limpar Filtros
            </Button>
          </Box>
        </Paper>
      )}
      
      {/* Resumo de estatísticas */}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Total de Impactos
              </Typography>
              <Typography variant="h3">
                {totalCount}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Impactos Significativos
              </Typography>
              <Typography variant="h3">
                {impacts.filter(i => i.significant).length}
              </Typography>
              <Typography color="text.secondary">
                nesta página
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Intensidade Média
              </Typography>
              <Typography variant="h3">
                {impacts.length > 0 
                  ? (impacts.reduce((acc, i) => acc + i.intensity, 0) / impacts.length).toFixed(1) 
                  : '-'}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        
        
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Último Impacto
              </Typography>
              <Typography variant="h3">
                {impacts.length > 0 
                  ? new Date(impacts[0].timestamp).toLocaleDateString() 
                  : '-'}
              </Typography>
              <Typography color="text.secondary">
                {impacts.length > 0 
                  ? new Date(impacts[0].timestamp).toLocaleTimeString() 
                  : ''}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
      
      {/* Tabela de Impactos */}
      <Paper sx={{ width: '100%', overflow: 'hidden' }}>
        <TableContainer sx={{ maxHeight: 440 }}>
          <Table stickyHeader aria-label="tabela de impactos">
            <TableHead>
              <TableRow>
                <TableCell>Data/Hora</TableCell>
                <TableCell>Dispositivo</TableCell>
                <TableCell>Intensidade</TableCell>
                <TableCell>Aceleração Total</TableCell>
                <TableCell>Aceleração XYZ</TableCell>
                <TableCell>Giro Total</TableCell>
                <TableCell>Giro XYZ</TableCell>
                <TableCell>HIC</TableCell>
                <TableCell>BrIC</TableCell>
                <TableCell>Severidade</TableCell>
                <TableCell>Significativo</TableCell>
                <TableCell>Ações</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {loading ? (
                <TableRow>
                  <TableCell colSpan={12} align="center">
                    <CircularProgress />
                  </TableCell>
                </TableRow>
              ) : impacts.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={12} align="center">
                    Nenhum impacto encontrado
                  </TableCell>
                </TableRow>
              ) : (
                impacts.map((impact) => (
                  <TableRow key={impact.id}>
                    <TableCell>
                      {new Date(impact.timestamp).toLocaleString()}
                    </TableCell>
                    <TableCell>
                      {impact.devices?.name || 'Desconhecido'}
                    </TableCell>
                    <TableCell>
                      {impact.intensity.toFixed(1)}
                    </TableCell>
                    <TableCell>
                      {impact.accel_total ? impact.accel_total.toFixed(2) : '-'}
                    </TableCell>
                    <TableCell>
                      {impact.accel_x ? (
                        <>
                          X: {impact.accel_x.toFixed(2)}<br />
                          Y: {impact.accel_y.toFixed(2)}<br />
                          Z: {impact.accel_z.toFixed(2)}
                        </>
                      ) : '-'}
                    </TableCell>
                    <TableCell>
                      {impact.gyro_total ? impact.gyro_total.toFixed(2) : '-'}
                    </TableCell>
                    <TableCell>
                      {impact.gyro_x ? (
                        <>
                          X: {impact.gyro_x.toFixed(2)}<br />
                          Y: {impact.gyro_y.toFixed(2)}<br />
                          Z: {impact.gyro_z.toFixed(2)}
                        </>
                      ) : '-'}
                    </TableCell>
                    <TableCell>
                      {impact.impact_details && impact.impact_details
                        ? impact.impact_details.hic_value.toFixed(1)
                        : '-'}
                    </TableCell>
                    <TableCell>
                      {impact.impact_details && impact.impact_details
                        ? impact.impact_details.bric_value.toFixed(2)
                        : '-'}
                    </TableCell>
                    <TableCell>
                      {impact.impact_details && impact.impact_details ? (
                        <Chip 
                          label={impact.impact_details.impact_severity} 
                          color={getSeverityColor(impact.impact_details.impact_severity)}
                          size="small"
                        />
                      ) : '-'}
                    </TableCell>
                    <TableCell>
                      <Chip 
                        label={impact.significant ? 'Sim' : 'Não'} 
                        color={impact.significant ? 'primary' : 'default'}
                        size="small"
                        variant={impact.significant ? 'filled' : 'outlined'}
                      />
                    </TableCell>
                    <TableCell>
                      <IconButton 
                        size="small" 
                        color="primary"
                        onClick={() => fetchImpactDetails(impact)}
                        disabled={detailLoading}
                      >
                        <InfoIcon />
                      </IconButton>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </TableContainer>
        
        <TablePagination
          rowsPerPageOptions={[5, 10, 25, 50]}
          component="div"
          count={totalCount}
          rowsPerPage={rowsPerPage}
          page={page}
          onPageChange={handleChangePage}
          onRowsPerPageChange={handleChangeRowsPerPage}
          labelRowsPerPage="Linhas por página:"
          labelDisplayedRows={({ from, to, count }) => `${from}-${to} de ${count}`}
        />
      </Paper>
      
      {/* Diálogo de Detalhes do Impacto */}
      <Dialog 
        open={detailsOpen} 
        onClose={handleCloseDetails}
        maxWidth="lg"
        fullWidth
      >
        <DialogTitle>
          Detalhes do Impacto
          {selectedImpact && (
            <Typography variant="subtitle2" color="text.secondary">
              {new Date(selectedImpact.timestamp).toLocaleString()}
            </Typography>
          )}
        </DialogTitle>
        
        <DialogContent dividers>
          {detailLoading ? (
            <Box sx={{ display: 'flex', justifyContent: 'center', p: 3 }}>
              <CircularProgress />
            </Box>
          ) : (
            <Grid container spacing={3}>
              {/* Informações básicas */}
              <Grid item xs={12} md={6}>
                <Card variant="outlined" sx={{ height: '100%' }}>
                  <CardContent>
                    <Typography variant="h6" gutterBottom>
                      Informações do Impacto
                    </Typography>
                    
                    <Grid container spacing={2}>
                      <Grid item xs={6}>
                        <Typography variant="body2" color="text.secondary">
                          Dispositivo
                        </Typography>
                        <Typography variant="body1" gutterBottom>
                          {selectedImpact?.devices?.name || 'Desconhecido'}
                        </Typography>
                      </Grid>
                      
                      <Grid item xs={6}>
                        <Typography variant="body2" color="text.secondary">
                          Intensidade
                        </Typography>
                        <Typography variant="body1" gutterBottom>
                          {selectedImpact?.intensity.toFixed(1)}
                        </Typography>
                      </Grid>
                      
                      <Grid item xs={6}>
                        <Typography variant="body2" color="text.secondary">
                          Significativo
                        </Typography>
                        <Typography variant="body1" gutterBottom>
                          {selectedImpact?.significant ? 'Sim' : 'Não'}
                        </Typography>
                      </Grid>
                      
                      <Grid item xs={6}>
                        <Typography variant="body2" color="text.secondary">
                          Temperatura
                        </Typography>
                        <Typography variant="body1" gutterBottom>
                          {selectedImpact?.temperature ? `${selectedImpact.temperature.toFixed(1)}°C` : '-'}
                        </Typography>
                      </Grid>
                      
                      <Grid item xs={6}>
                        <Typography variant="body2" color="text.secondary">
                          Pressão
                        </Typography>
                        <Typography variant="body1" gutterBottom>
                          {selectedImpact?.pressure ? `${selectedImpact.pressure.toFixed(1)} hPa` : '-'}
                        </Typography>
                      </Grid>
                      
                      <Grid item xs={12}>
                        <Typography variant="body2" color="text.secondary">
                          ID do Impacto
                        </Typography>
                        <Typography variant="body1" gutterBottom sx={{ wordBreak: 'break-all' }}>
                          {selectedImpact?.id}
                        </Typography>
                      </Grid>
                    </Grid>
                  </CardContent>
                </Card>
              </Grid>
              
              {/* Métricas principais */}
              <Grid item xs={12} md={6}>
                <Card variant="outlined" sx={{ height: '100%' }}>
                  <CardContent>
                    <Typography variant="h6" gutterBottom>
                      Métricas de Análise
                    </Typography>
                    
                    <Grid container spacing={2}>
                      <Grid item xs={6}>
                        <Typography variant="body2" color="text.secondary">
                          HIC (Head Injury Criterion)
                        </Typography>
                        <Typography variant="h5" gutterBottom color={
                          impactDetail?.details?.hic_value > 250 ? 'error.main' : 'text.primary'
                        }>
                          {impactDetail?.details?.hic_value.toFixed(1) || '-'}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          Valor crítico: &gt; 250
                        </Typography>
                      </Grid>
                      
                      <Grid item xs={6}>
                        <Typography variant="body2" color="text.secondary">
                          BrIC (Brain Injury Criterion)
                        </Typography>
                        <Typography variant="h5" gutterBottom color={
                          impactDetail?.details?.bric_value > 0.5 ? 'error.main' : 'text.primary'
                        }>
                          {impactDetail?.details?.bric_value.toFixed(2) || '-'}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          Valor crítico: &gt; 0.5
                        </Typography>
                      </Grid>
                      
                      <Grid item xs={6}>
                        <Typography variant="body2" color="text.secondary">
                          Severidade do Impacto
                        </Typography>
                        {impactDetail?.details ? (
                          <Chip 
                            label={impactDetail.details.impact_severity} 
                            color={getSeverityColor(impactDetail.details.impact_severity)}
                            sx={{ mt: 1 }}
                          />
                        ) : (
                          <Typography variant="body1">-</Typography>
                        )}
                      </Grid>
                      
                      <Grid item xs={6}>
                        <Typography variant="body2" color="text.secondary">
                          Aceleração Máxima
                        </Typography>
                        <Typography variant="h5" gutterBottom>
                          {impactDetail?.sensorData.length 
                            ? Math.max(...impactDetail.sensorData.map(d => d.accel_total || 0)).toFixed(2)
                            : '-'} m/s²
                        </Typography>
                      </Grid>
                      
                      <Grid item xs={12}>
                        <Typography variant="body2" color="text.secondary">
                          Timestamp de Processamento
                        </Typography>
                        <Typography variant="body1">
                          {impactDetail?.details?.created_at 
                            ? new Date(impactDetail.details.created_at).toLocaleString()
                            : '-'}
                        </Typography>
                      </Grid>
                    </Grid>
                  </CardContent>
                </Card>
              </Grid>
              
              {/* Gráfico de visualização */}
              <Grid item xs={12}>
                <Card variant="outlined">
                  <CardContent>
                    <Typography variant="h6" gutterBottom>
                      Visualização do Impacto
                    </Typography>
                    
                    {chartData ? (
                      <Box sx={{ height: 300 }}>
                        <Line 
                          data={chartData} 
                          options={{
                            responsive: true,
                            maintainAspectRatio: false,
                            interaction: {
                              mode: 'index',
                              intersect: false,
                            },
                            plugins: {
                              tooltip: {
                                enabled: true,
                              },
                            },
                            scales: {
                              y: {
                                title: {
                                  display: true,
                                  text: 'Aceleração (m/s²)'
                                }
                              },
                              x: {
                                title: {
                                  display: true,
                                  text: 'Tempo'
                                }
                              }
                            }
                          }}
                        />
                      </Box>
                    ) : (
                      <Typography variant="body1" color="text.secondary" sx={{ textAlign: 'center', p: 3 }}>
                        Sem dados sensoriais disponíveis para este impacto
                      </Typography>
                    )}
                  </CardContent>
                </Card>
              </Grid>
            </Grid>
          )}
        </DialogContent>
        
        <DialogActions>
          <Button onClick={handleCloseDetails}>Fechar</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}