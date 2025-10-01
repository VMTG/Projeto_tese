import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import Login from './components/Auth/Login';
import Register from './components/Auth/Register';
import MainLayout from './components/Layout/MainLayout';
import Dashboard from './components/Dashboard/Dashboard';
import DeviceList from './components/Devices/DeviceList';
import DeviceDetail from './components/Devices/DeviceDetail';
import Analytics from './components/Analytics/Analytics';
import Settings from './components/Settings/Settings';
import ImpactAnalysis from './components/Analytics/ImpactAnalysis';
import ImpactDetail from './components/Devices/ImpactDetail';

// Rota protegida que redireciona para login se não autenticado
function ProtectedRoute({ children }) {
  const { user, loading } = useAuth();
  
  if (loading) return <div>Carregando...</div>;
  
  if (!user) {
    return <Navigate to="/login" />;
  }
  
  return children;
}

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          
          <Route 
            path="/" 
            element={
              <ProtectedRoute>
                <MainLayout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Navigate to="/dashboard" />} />
            <Route path="dashboard" element={<Dashboard />} />
            <Route path="devices" element={<DeviceList />} />
            <Route path="devices/:deviceId" element={<DeviceDetail />} />
            <Route path="analytics" element={<Analytics />} />
            <Route path="impactanalysis" element={<ImpactAnalysis />} />
            <Route path="devices/impact/:impactId" element={<ImpactDetail />} />
            <Route path="settings" element={<Settings />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;