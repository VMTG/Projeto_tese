import { useState } from 'react';
import { 
  Box, Typography, Grid, Card, CardContent, 
  FormControl, InputLabel, Select, MenuItem
} from '@mui/material';
import { Line, Bar } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
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
  BarElement,
  Title,
  Tooltip,
  Legend
);

export default function Analytics() {
  const [timeRange, setTimeRange] = useState('24h');
  
  // Dados simulados para os gráficos de análise
  const impactData = {
    labels: ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'],
    datasets: [
      {
        label: 'Impactos Totais',
        data: [12, 19, 3, 5, 2, 3, 9],
        backgroundColor: 'rgba(53, 162, 235, 0.5)',
      },
      {
        label: 'Impactos Significativos',
        data: [2, 4, 1, 0, 1, 0, 3],
        backgroundColor: 'rgba(255, 99, 132, 0.5)',
      },
    ],
  };
  
  const intensityData = {
    labels: ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'],
    datasets: [
      {
        label: 'Intensidade Média (g)',
        data: [5.3, 7.2, 4.8, 5.1, 6.0, 4.5, 6.8],
        borderColor: 'rgb(255, 99, 132)',
        backgroundColor: 'rgba(255, 99, 132, 0.5)',
      },
      {
        label: 'Intensidade Máxima (g)',
        data: [8.5, 12.1, 7.3, 7.9, 9.2, 6.8, 11.4],
        borderColor: 'rgb(53, 162, 235)',
        backgroundColor: 'rgba(53, 162, 235, 0.5)',
      },
    ],
  };
  
  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
        <Typography variant="h4" component="h1">
          Análises
        </Typography>
        
        <FormControl sx={{ minWidth: 120 }}>
          <InputLabel>Período</InputLabel>
          <Select
            value={timeRange}
            label="Período"
            onChange={(e) => setTimeRange(e.target.value)}
            size="small"
          >
            <MenuItem value="24h">Últimas 24 horas</MenuItem>
            <MenuItem value="7d">Últimos 7 dias</MenuItem>
            <MenuItem value="30d">Últimos 30 dias</MenuItem>
            <MenuItem value="90d">Últimos 90 dias</MenuItem>
          </Select>
        </FormControl>
      </Box>
      
      <Grid container spacing={3}>
        <Grid item xs={12}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Número de Impactos Detectados
              </Typography>
              <Box sx={{ height: 300 }}>
                <Bar 
                  data={impactData} 
                  options={{
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                      legend: {
                        position: 'top',
                      },
                    },
                  }}
                />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={12}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Intensidade de Impacto
              </Typography>
              <Box sx={{ height: 300 }}>
                <Line 
                  data={intensityData} 
                  options={{
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                      legend: {
                        position: 'top',
                      },
                    },
                  }}
                />
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}