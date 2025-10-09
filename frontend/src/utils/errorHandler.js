export function handleNetworkError(error) {
  console.error('Network error:', error);
  return 'Network connection failed';
}

export function handleContractError(error) {
  console.error('Contract error:', error);
  return 'Transaction failed';
}
