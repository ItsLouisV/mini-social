import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Đặt CORS ngay trong function để Supabase Dashboard bundler không phải tải
// file nằm ngoài thư mục hidden-passcode-recovery.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const hashCode = async (userId: string, code: string, pepper: string) => {
  const bytes = new TextEncoder().encode(`${userId}:${code}:${pepper}`);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
};

const sameText = (left: string, right: string) => {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index++) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
};

const maskEmail = (email: string) => {
  const [name, domain] = email.split("@");
  if (!domain) return email;
  const visible = name.slice(0, Math.min(2, name.length));
  return `${visible}${"*".repeat(Math.max(2, name.length - visible.length))}@${domain}`;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // Mặc định tắt cho tới khi có domain gửi mail và các secret cần thiết.
  // Chỉ bật lại bằng secret ENABLE_HIDDEN_PASSCODE_RECOVERY=true.
  if (Deno.env.get("ENABLE_HIDDEN_PASSCODE_RECOVERY") !== "true") {
    return json({ error: "Khôi phục mã PIN qua email đang tạm thời không khả dụng." }, 503);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const resendKey = Deno.env.get("RESEND_API_KEY");
  const emailFrom = Deno.env.get("RECOVERY_EMAIL_FROM");
  const pepper = Deno.env.get("PASSCODE_OTP_PEPPER");
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !pepper) {
    return json({ error: "Dịch vụ khôi phục chưa được cấu hình." }, 503);
  }

  const authorization = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user?.email) return json({ error: "Phiên đăng nhập không hợp lệ." }, 401);

  let payload: { action?: string; code?: string; password?: string };
  try {
    payload = await req.json();
  } catch (_) {
    return json({ error: "Dữ liệu không hợp lệ." }, 400);
  }

  if (payload.action === "request") {
    if (!resendKey || !emailFrom) {
      return json({ error: "Dịch vụ gửi email chưa được cấu hình." }, 503);
    }

    const { data: previous } = await admin
      .from("hidden_passcode_recovery_codes")
      .select("last_sent_at")
      .eq("user_id", user.id)
      .maybeSingle();
    if (previous?.last_sent_at && Date.now() - Date.parse(previous.last_sent_at) < 60_000) {
      return json({ error: "Vui lòng chờ 60 giây trước khi gửi lại mã." }, 429);
    }

    const random = new Uint32Array(1);
    crypto.getRandomValues(random);
    const code = String(100000 + (random[0] % 900000));
    const codeHash = await hashCode(user.id, code, pepper);
    const expiresAt = new Date(Date.now() + 2 * 60_000).toISOString();
    const { error: storeError } = await admin.from("hidden_passcode_recovery_codes").upsert({
      user_id: user.id,
      code_hash: codeHash,
      expires_at: expiresAt,
      attempts: 0,
      last_sent_at: new Date().toISOString(),
      created_at: new Date().toISOString(),
    });
    if (storeError) return json({ error: "Không thể tạo mã xác minh." }, 500);

    const mailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: emailFrom,
        to: [user.email],
        subject: "Mã xác minh đặt lại PIN cuộc trò chuyện ẩn",
        text: `Mã xác minh của bạn là: ${code}. Mã có hiệu lực trong 2 phút. Nếu bạn không yêu cầu, hãy bỏ qua email này.`,
        html: `<p>Mã xác minh đặt lại PIN cuộc trò chuyện ẩn:</p><p style="font-size:30px;font-weight:700;letter-spacing:6px">${code}</p><p>Mã có hiệu lực trong 2 phút. Không chia sẻ mã này với bất kỳ ai.</p>`,
      }),
    });
    if (!mailResponse.ok) {
      await admin.from("hidden_passcode_recovery_codes").delete().eq("user_id", user.id);
      console.error("Recovery email failed", mailResponse.status, await mailResponse.text());
      return json({ error: "Không thể gửi email xác minh." }, 502);
    }
    return json({ sent: true, email: maskEmail(user.email), expiresIn: 120 });
  }

  if (payload.action === "verify") {
    const code = payload.code?.trim() ?? "";
    const password = payload.password ?? "";
    if (!/^\d{6}$/.test(code) || password.length === 0) {
      return json({ error: "Vui lòng nhập đủ mã 6 số và mật khẩu tài khoản." }, 400);
    }

    const { data: record } = await admin
      .from("hidden_passcode_recovery_codes")
      .select("code_hash, expires_at, attempts")
      .eq("user_id", user.id)
      .maybeSingle();
    if (!record || Date.parse(record.expires_at) <= Date.now()) {
      if (record) await admin.from("hidden_passcode_recovery_codes").delete().eq("user_id", user.id);
      return json({ error: "Mã đã hết hạn. Vui lòng gửi mã mới." }, 400);
    }
    if (record.attempts >= 5) {
      return json({ error: "Bạn đã nhập sai quá nhiều lần. Vui lòng gửi mã mới." }, 429);
    }

    const passwordResponse = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { apikey: anonKey, "Content-Type": "application/json" },
      body: JSON.stringify({ email: user.email, password }),
    });
    const passwordBody = passwordResponse.ok ? await passwordResponse.json() : null;
    if (!passwordResponse.ok || passwordBody?.user?.id !== user.id) {
      await admin.from("hidden_passcode_recovery_codes").update({ attempts: record.attempts + 1 }).eq("user_id", user.id);
      return json({ error: "Mật khẩu tài khoản không chính xác." }, 401);
    }

    const submittedHash = await hashCode(user.id, code, pepper);
    if (!sameText(submittedHash, record.code_hash)) {
      await admin.from("hidden_passcode_recovery_codes").update({ attempts: record.attempts + 1 }).eq("user_id", user.id);
      return json({ error: "Mã xác minh không chính xác." }, 400);
    }

    await admin.from("hidden_passcode_recovery_codes").delete().eq("user_id", user.id);
    return json({ verified: true });
  }

  return json({ error: "Yêu cầu không hợp lệ." }, 400);
});
