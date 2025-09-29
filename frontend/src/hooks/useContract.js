import { useContractRead, useContractWrite } from 'wagmi';
import { PAYMENT_STREAM_ADDRESS } from '../config/contracts';

export function usePaymentStream() {
  const { write: createStream } = useContractWrite({
    address: PAYMENT_STREAM_ADDRESS,
    functionName: 'createStream',
  });

  return { createStream };
}
