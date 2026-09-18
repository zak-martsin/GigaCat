-- Profile creation is internal Auth trigger infrastructure. Data API roles must
-- not be able to invoke this SECURITY DEFINER function as an RPC endpoint.
revoke execute
on function public.handle_new_user()
from public, anon, authenticated, service_role;
