import React from 'react';
import { createRoot } from 'react-dom/client';
import './index.css';
import App from './App';
import reportWebVitals from './reportWebVitals';

import '@fontsource/roboto/300.css';
import '@fontsource/roboto/400.css';
import '@fontsource/roboto/500.css';
import '@fontsource/roboto/700.css';

// Cria um root utilizando a nova API do React 18
const root = createRoot(document.getElementById('root'));

// Renderiza o App no root
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

reportWebVitals();