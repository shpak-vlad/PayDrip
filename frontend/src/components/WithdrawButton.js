import React from 'react';

export default function WithdrawButton({ streamId }) {
  const handleWithdraw = () => {
    console.log('Withdrawing from stream', streamId);
  };

  return (
    <button 
      onClick={handleWithdraw}
      className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
    >
      Withdraw
    </button>
  );
}
