import React, { useState } from 'react';

export default function CreateStreamForm() {
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');
  const [duration, setDuration] = useState('');

  return (
    <div className="bg-white rounded-xl shadow-lg p-6">
      <h2 className="text-2xl font-bold mb-6">Create Payment Stream</h2>
      <form className="space-y-4">
        <input 
          type="text" 
          placeholder="Recipient Address"
          value={recipient}
          onChange={(e) => setRecipient(e.target.value)}
          className="w-full px-4 py-3 border rounded-lg"
        />
        <input 
          type="number" 
          placeholder="Amount"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          className="w-full px-4 py-3 border rounded-lg"
        />
        <input 
          type="number" 
          placeholder="Duration (days)"
          value={duration}
          onChange={(e) => setDuration(e.target.value)}
          className="w-full px-4 py-3 border rounded-lg"
        />
        <button className="w-full bg-blue-600 text-white py-3 rounded-lg hover:bg-blue-700">
          Create Stream
        </button>
      </form>
    </div>
  );
}
