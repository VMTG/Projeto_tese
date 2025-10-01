import { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabaseClient';
import { 
  Box, Typography, Grid, Card, CardContent, 
  CircularProgress, Alert, Table, TableBody, TableCell,
  TableContainer, TableHead, TableRow, Paper, Chip
} from '@mui/material';
import { Line, Pie } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  ArcElement,
} from 'chart.js';

// Registrar componentes ChartJS
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  ArcElement
);

export default function Dashboard() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [devices, setDevices] = useState([]);
  const [impactEvents, setImpactEvents] = useState([]);
  const [impactStats, setImpactStats] = useState({
    totalImpacts: 0,
    maxHIC: 0,
    maxBRIC: 0,
    highSeverityCount: 0
  });
  const [impactTrend, setImpactTrend] = useState([]);
  const [directionDistribution, setDirectionDistribution] = useState({});
  
  useEffect(() => {
    async function fetchDashboardData() {
      try {
        setLoading(true);
        setError(null);
        
        // Buscar dispositivos
        const { data: devicesData, error: devicesError } = await supabase
          .from('devices')
          .select('*');
          
        if (devicesError) throw devicesError;
        setDevices(devicesData || []);
        
        // Buscar eventos de impacto recentes com detalhes
        const { data: impactData, error: impactError } = await supabase
          .from('impact_events')
          .select(`
            id,
            device_id,
            timestamp,
            intensity,
            accel_x,
            accel_y,
            accel_z,
            accel_total,
            devices(name)
          `)
          .order('timestamp', { ascending: false })
          .limit(10);
          
        if (impactError) throw impactError;
        
        // Buscar os detalhes correspondentes a esses impactos
        const impactIds = impactData.map(impact => impact.id);
        const { data: detailsData, error: detailsQueryError } = await supabase
          .from('impact_details')
          .select('*')
          .in('impact_event_id', impactIds);
        
        if (detailsQueryError) throw detailsQueryError;
        
        // Combinar os detalhes com os eventos de impacto
        const impactsWithDetails = impactData.map(impact => {
          const detail = detailsData.find(d => d.impact_event_id === impact.id);
          return {
            ...impact,
            detail: detail || null
          };
        });
        
        setImpactEvents(impactsWithDetails);
        
        // Buscar estatísticas gerais
        const { data: allDetails, error: allDetailsError } = await supabase
          .from('impact_details')
          .select('*');
          
        if (allDetailsError) throw allDetailsError;
        
        // Calcular estatísticas
        if (allDetails && allDetails.length > 0) {
          const maxHIC = Math.max(...allDetails.map(detail => detail.hic_value));
          const maxBRIC = Math.max(...allDetails.map(detail => detail.bric_value));
          const highSeverityCount = allDetails.filter(detail => 
            detail.impact_severity === '🔴 Alto Risco').length;
          
          setImpactStats({
            totalImpacts: allDetails.length,
            maxHIC,
            maxBRIC,
            highSeverityCount
          });
        }
        
        // Buscar dados para o gráfico de tendência (últimos 30 dias)
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        
        const { data: trendData, error: trendError } = await supabase
          .from('impact_events')
          .select('timestamp')
          .gte('timestamp', thirtyDaysAgo.toISOString());
          
        if (trendError) throw trendError;
        
        // Agrupar por dia para o gráfico de tendência
        const groupedByDay = {};
        (trendData || []).forEach(impact => {
          const date = new Date(impact.timestamp).toISOString().split('T')[0];
          groupedByDay[date] = (groupedByDay[date] || 0) + 1;
        });
        
        // Ordenar por data
        const trendByDay = Object.entries(groupedByDay)
          .map(([date, count]) => ({ date, count }))
          .sort((a, b) => new Date(a.date) - new Date(b.date));
          
        setImpactTrend(trendByDay);
        
        // Cálculo da distribuição de direção
        // Vamos usar os dados de aceleração para estimar a direção
        const directionCounts = {
          'Frente': 0,
          'Trás': 0,
          'Direita': 0,
          'Esquerda': 0,
          'Cima': 0,
          'Baixo': 0
        };
        
        // Determinar direção com base nos componentes de aceleração
        impactData.forEach(impact => {
          if (!impact.accel_x && !impact.accel_y && !impact.accel_z) {
            // Se não temos dados de aceleração, não podemos determinar direção
            return;
          }
          
          // Determinar o eixo dominante e direção
          const absX = Math.abs(impact.accel_x || 0);
          const absY = Math.abs(impact.accel_y || 0);
          const absZ = Math.abs(impact.accel_z || 0);
          
          if (absX > absY && absX > absZ) {
            // X é o eixo dominante
            if (impact.accel_x > 0) {
              directionCounts['Direita']++;
            } else {
              directionCounts['Esquerda']++;
            }
          } else if (absY > absX && absY > absZ) {
            // Y é o eixo dominante
            if (impact.accel_y > 0) {
              directionCounts['Frente']++;
            } else {
              directionCounts['Trás']++;
            }
          } else if (absZ > absX && absZ > absY) {
            // Z é o eixo dominante
            if (impact.accel_z > 0) {
              directionCounts['Cima']++;
            } else {
              directionCounts['Baixo']++;
            }
          } else {
            // Se não há eixo claramente dominante, distribuir uniformemente
            // ou você pode implementar uma lógica mais sofisticada aqui
            const randomDir = Math.floor(Math.random() * 6);
            const directions = ['Frente', 'Trás', 'Direita', 'Esquerda', 'Cima', 'Baixo'];
            directionCounts[directions[randomDir]]++;
          }
        });
        
        setDirectionDistribution(directionCounts);
        
      } catch (error) {
        console.error('Erro ao buscar dados do dashboard:', error);
        setError(error.message);
      } finally {
        setLoading(false);
      }
    }
    
    fetchDashboardData();
  }, []);
  
  // Preparar dados para o gráfico de tendência
  const trendChartData = {
    labels: impactTrend.map(item => item.date),
    datasets: [
      {
        label: 'Número de Impactos',
        data: impactTrend.map(item => item.count),
        borderColor: 'rgb(53, 162, 235)',
        backgroundColor: 'rgba(53, 162, 235, 0.5)',
        fill: true,
      },
    ],
  };
  
  // Preparar dados para o gráfico de distribuição por direção
  const directionChartData = {
    labels: Object.keys(directionDistribution),
    datasets: [
      {
        label: 'Distribuição por Direção',
        data: Object.values(directionDistribution),
        backgroundColor: [
          'rgba(255, 99, 132, 0.7)',
          'rgba(54, 162, 235, 0.7)',
          'rgba(255, 206, 86, 0.7)',
          'rgba(75, 192, 192, 0.7)',
          'rgba(153, 102, 255, 0.7)',
          'rgba(255, 159, 64, 0.7)',
        ],
        borderColor: [
          'rgba(255, 99, 132, 1)',
          'rgba(54, 162, 235, 1)',
          'rgba(255, 206, 86, 1)',
          'rgba(75, 192, 192, 1)',
          'rgba(153, 102, 255, 1)',
          'rgba(255, 159, 64, 1)',
        ],
        borderWidth: 1,
      },
    ],
  };
  
  // Função para determinar a cor baseada na severidade
  const getSeverityColor = (severity) => {
    switch(severity) {
      case 'Alto':
        return 'error';
      case 'Médio':
        return 'warning';
      case 'Baixo':
        return 'success';
      default:
        return 'default';
    }
  };
  
  if (loading) return <CircularProgress />;
  
  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        Dashboard de Monitoramento de Impactos
      </Typography>
      
      {error && <Alert severity="error" sx={{ mb: 3 }}>{error}</Alert>}
      
      <Grid container spacing={3}>
        {/* Card - Total de Impactos */}
        <Grid item xs={12} md={3}>
          <Card sx={{ borderLeft: '4px solid #4e73df', height: '100%' }}>
            <CardContent>
              <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                TOTAL DE IMPACTOS
              </Typography>
              <Typography variant="h3">
                {impactStats.totalImpacts}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        
        {/* Card - HIC Máximo */}
        <Grid item xs={12} md={3}>
          <Card sx={{ borderLeft: '4px solid #1cc88a', height: '100%' }}>
            <CardContent>
              <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                HIC MÁXIMO
              </Typography>
              <Typography variant="h3">
                {impactStats.maxHIC.toFixed(1)}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        
        {/* Card - BRIC Máximo */}
        <Grid item xs={12} md={3}>
          <Card sx={{ borderLeft: '4px solid #36b9cc', height: '100%' }}>
            <CardContent>
              <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                BRIC MÁXIMO
              </Typography>
              <Typography variant="h3">
                {impactStats.maxBRIC.toFixed(2)}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        
        {/* Card - Impactos de Alta Severidade */}
        <Grid item xs={12} md={3}>
          <Card sx={{ borderLeft: '4px solid #e74a3b', height: '100%' }}>
            <CardContent>
              <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                IMPACTOS DE ALTO RISCO
              </Typography>
              <Typography variant="h3">
                {impactStats.highSeverityCount}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        
        {/* Gráfico de tendência de impactos */}
        <Grid item xs={12} md={8}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Tendência de Impactos ao Longo do Tempo
              </Typography>
              <Box sx={{ height: 300 }}>
                <Line 
                  data={trendChartData} 
                  options={{
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                      x: {
                        title: {
                          display: true,
                          text: 'Data'
                        }
                      },
                      y: {
                        beginAtZero: true,
                        title: {
                          display: true,
                          text: 'Número de Impactos'
                        }
                      }
                    }
                  }}
                />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        
        {/* Gráfico de distribuição por direção */}
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Distribuição por Direção do Impacto
              </Typography>
              <Box sx={{ height: 300, display: 'flex', justifyContent: 'center' }}>
                <Pie 
                  data={directionChartData} 
                  options={{
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                      legend: {
                        position: 'bottom'
                      }
                    }
                  }}
                />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        
        {/* Tabela de impactos recentes */}
        <Grid item xs={12}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Impactos Recentes
              </Typography>
              <TableContainer component={Paper}>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Data/Hora</TableCell>
                      <TableCell>Dispositivo</TableCell>
                      <TableCell align="center">Intensidade</TableCell>
                      <TableCell align="center">HIC</TableCell>
                      <TableCell align="center">BRIC</TableCell>
                      <TableCell align="center">Severidade</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                  {impactEvents.map((impact) => (
                      <TableRow 
                        key={impact.id} 
                        sx={{ 
                          '&:last-child td, &:last-child th': { border: 0 },
                          backgroundColor: impact.detail?.impact_severity === 'Alto' 
                            ? 'rgba(231, 74, 59, 0.05)' 
                            : impact.detail?.impact_severity === 'Médio'
                              ? 'rgba(246, 194, 62, 0.05)'
                              : 'inherit'
                        }}
                      >
                        <TableCell component="th" scope="row">
                          {new Date(impact.timestamp).toLocaleString()}
                        </TableCell>
                        <TableCell>{impact.devices?.name || 'Desconhecido'}</TableCell>
                        <TableCell align="center">{impact.intensity?.toFixed(1) || 'N/A'}</TableCell>
                        <TableCell align="center">
                          {impact.detail?.hic_value?.toFixed(1) || 'N/A'}
                        </TableCell>
                        <TableCell align="center">
                          {impact.detail?.bric_value?.toFixed(2) || 'N/A'}
                        </TableCell>
                        <TableCell align="center">
                          <Chip 
                            label={impact.detail?.impact_severity || 'Não processado'} 
                            color={getSeverityColor(impact.detail?.impact_severity)}
                            size="small"
                          />
                        </TableCell>
                      </TableRow>
                    ))}
                    {impactEvents.length === 0 && (
                      <TableRow>
                        <TableCell colSpan={6} align="center">
                          Nenhum impacto registrado recentemente
                        </TableCell>
                      </TableRow>
                    )}
                  </TableBody>
                </Table>
              </TableContainer>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}