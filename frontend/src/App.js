import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Dashboard from './pages/Dashboard';
import StreamDetails from './pages/StreamDetails';
import WalletConnect from './components/WalletConnect';

function App() {
  return (
    <BrowserRouter>
      <div className="min-h-screen">
        <nav className="bg-white shadow-sm border-b">
          <div className="container mx-auto px-4 py-4 flex justify-between items-center">
            <h1 className="text-2xl font-bold text-blue-600">PayDrip</h1>
            <WalletConnect />
          </div>
        </nav>
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/stream/:streamId" element={<StreamDetails />} />
        </Routes>
      </div>
    </BrowserRouter>
  );
}

export default App;
