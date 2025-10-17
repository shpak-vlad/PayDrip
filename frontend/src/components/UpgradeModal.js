import React from 'react';

export default function UpgradeModal({ isOpen, onClose }) {
  if (!isOpen) return null;
  
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
      <div className="bg-white rounded-xl p-6 max-w-md">
        <h2 className="text-2xl font-bold mb-4">Upgrade Contract</h2>
        <p className="text-gray-600 mb-6">Upgrade to V2 for new features</p>
        <button className="w-full bg-blue-600 text-white py-3 rounded-lg">
          Upgrade Now
        </button>
      </div>
    </div>
  );
}
