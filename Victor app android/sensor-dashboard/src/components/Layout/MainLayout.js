import { useState } from 'react';
import { Outlet, Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import { 
  AppBar, Toolbar, Typography, Button, Drawer, List, 
  ListItem, ListItemIcon, ListItemText, Box, IconButton
} from '@mui/material';
import { 
  Menu as MenuIcon, 
  Dashboard as DashboardIcon,
  Devices as DevicesIcon,
  Assessment as AssessmentIcon,
  Settings as SettingsIcon,
  Logout as LogoutIcon,
  Functions as FunctionsIcon
} from '@mui/icons-material';

export default function MainLayout() {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();
  const [drawerOpen, setDrawerOpen] = useState(false);

  const handleLogout = async () => {
    await signOut();
    navigate('/login');
  };

  return (
    <>
      <AppBar position="static">
        <Toolbar>
          <IconButton
            size="large"
            edge="start"
            color="inherit"
            aria-label="menu"
            sx={{ mr: 2 }}
            onClick={() => setDrawerOpen(true)}
          >
            <MenuIcon />
          </IconButton>
          <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
            Sensor Dashboard
          </Typography>
          {user ? (
            <Button color="inherit" onClick={handleLogout}>Logout</Button>
          ) : (
            <Button color="inherit" component={Link} to="/login">Login</Button>
          )}
        </Toolbar>
      </AppBar>
      
      <Drawer
        anchor="left"
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
      >
        <Box
          sx={{ width: 250 }}
          role="presentation"
          onClick={() => setDrawerOpen(false)}
        >
          <List>
            <ListItem button component={Link} to="/dashboard">
              <ListItemIcon><DashboardIcon /></ListItemIcon>
              <ListItemText primary="Dashboard" />
            </ListItem>
            <ListItem button component={Link} to="/devices">
              <ListItemIcon><DevicesIcon /></ListItemIcon>
              <ListItemText primary="Dispositivos" />
            </ListItem>
            <ListItem button component={Link} to="/analytics">
              <ListItemIcon><AssessmentIcon /></ListItemIcon>
              <ListItemText primary="Análises" />
            </ListItem>
            <ListItem button component={Link} to="/impactanalysis">
              <ListItemIcon><FunctionsIcon /></ListItemIcon>
              <ListItemText primary="Análise de Impactos" />
            </ListItem>
            <ListItem button component={Link} to="/settings">
              <ListItemIcon><SettingsIcon /></ListItemIcon>
              <ListItemText primary="Configurações" />
            </ListItem>
            {user && (
              <ListItem button onClick={handleLogout}>
                <ListItemIcon><LogoutIcon /></ListItemIcon>
                <ListItemText primary="Logout" />
              </ListItem>
            )}
          </List>
        </Box>
      </Drawer>
      
      <Box sx={{ p: 3 }}>
        <Outlet />
      </Box>
    </>
  );
}