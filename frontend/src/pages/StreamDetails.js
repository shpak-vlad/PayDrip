import React from 'react';
import { useParams } from 'react-router-dom';

export default function StreamDetails() {
  const { streamId } = useParams();
  
  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-6">Stream #{streamId}</h1>
      <div className="bg-white rounded-xl shadow-lg p-6">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <span className="text-gray-600">Status</span>
            <p className="text-lg font-semibold">Active</p>
          </div>
          <div>
            <span className="text-gray-600">Amount</span>
            <p className="text-lg font-semibold">1000 USDC</p>
          </div>
        </div>
      </div>
    </div>
  );
}
