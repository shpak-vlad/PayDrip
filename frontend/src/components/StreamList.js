import React from 'react';

export default function StreamList({ streams }) {
  return (
    <div className="space-y-4">
      <h2 className="text-2xl font-bold">Active Streams</h2>
      {streams?.map((stream, idx) => (
        <div key={idx} className="bg-white rounded-lg p-6 shadow">
          <div className="flex justify-between">
            <span className="font-semibold">Stream #{idx}</span>
            <span className="text-green-600">Active</span>
          </div>
        </div>
      ))}
    </div>
  );
}
