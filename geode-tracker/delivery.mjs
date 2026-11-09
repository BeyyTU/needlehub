// Coalesce bursts, wake again for arrivals during a send, and keep a slow safety poll.
export function createDeliveryScheduler(deliver,{delayMs=25,safetyMs=2000,onError=()=>{}}={}) {
  let working=false,requested=false,stopped=false,timer;
  function request() {
    if(stopped)return;requested=true;
    if(!working && !timer)timer=setTimeout(run,delayMs);
  }
  async function run() {
    timer=undefined;if(stopped)return;
    requested=false;working=true;
    try {await deliver();}catch(error){onError(error);}
    finally {working=false;if(requested)request();}
  }
  const safety=setInterval(request,safetyMs);
  return {request,stop(){stopped=true;clearTimeout(timer);clearInterval(safety);}};
}
