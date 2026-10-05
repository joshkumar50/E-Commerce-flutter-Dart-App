CREATE TABLE IF NOT EXISTS public.api_rate_limits (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
    call_count INT NOT NULL DEFAULT 1,
    UNIQUE(user_id, action, window_start)
);

CREATE OR REPLACE FUNCTION public.check_rate_limit(
    p_action TEXT,
    p_max INT,
    p_window_seconds INT
) RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_window TIMESTAMPTZ;
    v_count INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
    END IF;
    v_window := date_trunc('second', now()) - 
                (EXTRACT(EPOCH FROM now())::INT % p_window_seconds) * INTERVAL '1 second';
    INSERT INTO public.api_rate_limits (user_id, action, window_start, call_count)
    VALUES (v_user_id, p_action, v_window, 1)
    ON CONFLICT (user_id, action, window_start)
    DO UPDATE SET call_count = api_rate_limits.call_count + 1
    RETURNING call_count INTO v_count;
    IF v_count > p_max THEN
        RAISE EXCEPTION 'Rate limit exceeded for %' , p_action USING ERRCODE = 'P0014';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
