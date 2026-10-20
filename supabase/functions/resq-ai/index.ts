
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const systemPrompt =
  "Kamu adalah ResQ AI, asisten kebencanaan di Indonesia. " +
  "Jawab hanya tentang bencana, mitigasi, kesiapsiagaan, evakuasi, " +
  "keselamatan, P3K dasar, perlengkapan darurat, dan pemulihan " +
  "pascabencana. Tolak topik lain dengan sopan. " +
  "Gunakan bahasa Indonesia yang jelas, praktis, dan ringkas. " +
  "Jangan mengarang informasi bencana terkini. Arahkan pengguna " +
  "memeriksa BMKG, BNPB, atau BPBD. Jangan memberi diagnosis medis. " +
  "Jika tidak yakin, akui keterbatasanmu.";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return Response.json(
      { error: "Metode tidak diizinkan." },
      { status: 405, headers: corsHeaders },
    );
  }

  try {
    const apiKey = Deno.env.get("GEMINI_API_KEY");

    if (!apiKey) {
      return Response.json(
        { error: "Secret Gemini belum dikonfigurasi." },
        { status: 500, headers: corsHeaders },
      );
    }

    const body = await req.json();
    const message =
      typeof body.message === "string" ? body.message.trim() : "";

    if (!message || message.length > 4000) {
      return Response.json(
        { error: "Pertanyaan wajib diisi dan maksimal 4000 karakter." },
        { status: 400, headers: corsHeaders },
      );
    }

    const model = "gemini-3.5-flash-lite";

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          system_instruction: {
            parts: [{ text: systemPrompt }],
          },
          contents: [
            {
              role: "user",
              parts: [{ text: message }],
            },
          ],
          generationConfig: {
            temperature: 0.3,
            maxOutputTokens: 800,
          },
        }),
      },
    );

    if (!response.ok) {
      console.error("Gemini status:", response.status);

      return Response.json(
        { error: "Gemini gagal memproses pertanyaan." },
        { status: 502, headers: corsHeaders },
      );
    }

    const data = await response.json();
    const answer = data?.candidates?.[0]?.content?.parts
      ?.map((part: { text?: string }) => part.text ?? "")
      .join("\n")
      .trim();

    if (!answer) {
      return Response.json(
        { error: "Gemini tidak memberikan jawaban." },
        { status: 502, headers: corsHeaders },
      );
    }

    return Response.json(
      { answer },
      { headers: corsHeaders },
    );
  } catch (error) {
    console.error("ResQ AI error:", error);

    return Response.json(
      { error: "Terjadi kesalahan pada layanan ResQ AI." },
      { status: 500, headers: corsHeaders },
    );
  }
});
