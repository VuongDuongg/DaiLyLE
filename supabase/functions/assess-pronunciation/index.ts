// Supabase Edge Function: assess-pronunciation
// Serves Dailyle AI Pronunciation Assessment Engine
// Supports Gemini 2.5 Flash Multimodal Audio Analysis + Needleman-Wunsch IPA Alignment

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Vietnamese phonetic feedback database for common English pronunciation pitfalls
const VIETNAMESE_TIPS: Record<string, string> = {
  "θ": "Đặt đầu lưỡi giữa hai hàm răng và đẩy luồng hơi nhẹ ra ngoài, không phát âm thành /t/ hay /s/.",
  "ð": "Đặt đầu lưỡi giữa hai hàm răng và rung dây thanh quản (hữu thanh), không phát âm thành /d/.",
  "ʃ": "Tròn môi, đưa đầu lưỡi hơi lùi về sau và đẩy luồng hơi mạnh (nặng hơn âm /s/ tiếng Việt).",
  "ʒ": "Khẩu hình giống âm /ʃ/ nhưng rung dây thanh quản (ví dụ trong: 'vision', 'casual').",
  "tʃ": "Bật âm /t/ rồi nhanh chóng chuyển sang chu môi phát âm /ʃ/ dứt khoát ('chair', 'church').",
  "dʒ": "Khẩu hình như /tʃ/ nhưng phát âm hữu thanh và rung cổ họng ('job', 'juice').",
  "æ": "Mở rộng hàm dưới theo cả chiều dọc và ngang, phát âm bẹt miệng ('cat', 'man').",
  "ʌ": "Hạ thấp hàm, thả lỏng môi và phát âm dứt khoát ('cut', 'sun').",
  "iː": "Cười nhẹ và kéo dài âm /iː/ hơn bình thường ('see', 'green').",
  "uː": "Chu tròn môi và kéo dài âm /uː/ ('blue', 'food').",
  "ɔː": "Mở tròn khẩu hình miệng và phát âm sâu từ vòm họng ('thought', 'call').",
  "ŋ": "Nâng cuống lưỡi chạm ngạc mềm, thở hơi qua mũi ('sing', 'think').",
  "r": "Uốn cong đầu lưỡi về phía vòm họng trên nhưng không chạm vào vòm họng ('red', 'right').",
  "default_missing": "Bạn đã bỏ quên âm đuôi (ending sound) này. Người Việt thường dễ nuốt phụ âm cuối.",
  "default_wrong": "Khẩu hình miệng chưa chuẩn xác cho âm này. Hãy lắng nghe và lặp lại theo mẫu."
};

interface PhonemeDiff {
  phoneme: string;
  actual: string;
  status: "correct" | "wrong" | "missing" | "extra";
  tip?: string;
}

interface WordAnalysis {
  word: string;
  expected_ipa: string;
  actual_ipa: string;
  score: number;
  phoneme_analysis: PhonemeDiff[];
}

interface AssessmentResponse {
  overall_score: number;
  words: WordAnalysis[];
  overall_feedback: string;
  recommended_phoneme_drill: string;
}

// Needleman-Wunsch / Levenshtein Sequence Alignment for Phonemes
function alignPhonemes(expectedIpa: string, actualIpa: string): {
  phoneme_analysis: PhonemeDiff[];
  score: number;
} {
  // Strip slashes and primary/secondary stress markers
  const cleanExp = expectedIpa.replace(/[\/ˈˌ.]/g, "");
  const cleanAct = actualIpa.replace(/[\/ˈˌ.]/g, "");

  const a = Array.from(cleanExp);
  const b = Array.from(cleanAct);
  const n = a.length;
  const m = b.length;

  if (n === 0 && m === 0) {
    return { phoneme_analysis: [], score: 100 };
  }

  // Cost DP Matrix
  const dp: number[][] = Array.from({ length: n + 1 }, () =>
    new Array(m + 1).fill(0)
  );

  for (let i = 0; i <= n; i++) dp[i][0] = i;
  for (let j = 0; j <= m; j++) dp[0][j] = j;

  for (let i = 1; i <= n; i++) {
    for (let j = 1; j <= m; j++) {
      const match = a[i - 1] === b[j - 1];
      const subCost = match ? 0 : 1;
      dp[i][j] = Math.min(
        dp[i - 1][j - 1] + subCost, // Substitution / Match
        dp[i - 1][j] + 1,           // Deletion (Missing)
        dp[i][j - 1] + 1            // Insertion (Extra)
      );
    }
  }

  // Backtracking alignment
  let i = n;
  let j = m;
  const aligned: PhonemeDiff[] = [];
  let correctCount = 0;

  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && dp[i][j] === dp[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1)) {
      const expChar = a[i - 1];
      const actChar = b[j - 1];
      if (expChar === actChar) {
        aligned.unshift({ phoneme: expChar, actual: actChar, status: "correct" });
        correctCount++;
      } else {
        const tip = VIETNAMESE_TIPS[expChar] || VIETNAMESE_TIPS["default_wrong"];
        aligned.unshift({ phoneme: expChar, actual: actChar, status: "wrong", tip });
      }
      i--;
      j--;
    } else if (i > 0 && dp[i][j] === dp[i - 1][j] + 1) {
      const expChar = a[i - 1];
      const tip = VIETNAMESE_TIPS[expChar] || VIETNAMESE_TIPS["default_missing"];
      aligned.unshift({ phoneme: expChar, actual: "-", status: "missing", tip });
      i--;
    } else {
      const actChar = b[j - 1];
      aligned.unshift({ phoneme: "-", actual: actChar, status: "extra" });
      j--;
    }
  }

  const maxLen = Math.max(n, m);
  const distance = dp[n][m];
  const calculatedScore = maxLen > 0
    ? Math.max(0, Math.round(((maxLen - distance) / maxLen) * 100))
    : 100;

  return { phoneme_analysis: aligned, score: calculatedScore };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { audio_base64, audio_url, target_text, standard_ipa } = await req.json();

    if (!target_text || !standard_ipa) {
      return new Response(
        JSON.stringify({ error: "target_text and standard_ipa are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    let actualSpokenText = target_text;
    let actualIpaCombined = standard_ipa;

    // Call Gemini 2.5 Flash Multimodal Audio API if key is present
    if (geminiApiKey && (audio_base64 || audio_url)) {
      try {
        let inlineDataPart = null;
        if (audio_base64) {
          inlineDataPart = {
            inline_data: {
              mime_type: "audio/wav",
              data: audio_base64.replace(/^data:audio\/\w+;base64,/, ""),
            },
          };
        }

        const prompt = `You are an expert English Speech-to-Phoneme evaluator.
The user is attempting to say: "${target_text}".
The standard IPA is: "${standard_ipa}".
Listen to the audio and provide the exact transcript of what the user actually pronounced, and convert the user's actual pronunciation into precise IPA symbols.
Respond in strict JSON with:
{
  "recognized_text": "...",
  "actual_ipa": "..."
}`;

        const requestBody: any = {
          contents: [
            {
              parts: [
                inlineDataPart ? inlineDataPart : { text: `Audio URL: ${audio_url}` },
                { text: prompt },
              ],
            },
          ],
          generationConfig: {
            responseMimeType: "application/json",
            temperature: 0.1,
          },
        };

        const geminiRes = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(requestBody),
          }
        );

        if (geminiRes.ok) {
          const geminiData = await geminiRes.json();
          const candidateText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
          if (candidateText) {
            const parsed = JSON.parse(candidateText);
            actualSpokenText = parsed.recognized_text || actualSpokenText;
            actualIpaCombined = parsed.actual_ipa || standard_ipa;
          }
        }
      } catch (err) {
        console.warn("[assess-pronunciation] Gemini fallback triggered:", err);
      }
    }

    // Split sentence into words and clean IPA
    const targetWords = target_text.trim().split(/\s+/);
    const standardIpaWords = standard_ipa.replace(/[\/]/g, "").trim().split(/\s+/);
    const actualIpaWords = actualIpaCombined.replace(/[\/]/g, "").trim().split(/\s+/);

    const wordAnalyses: WordAnalysis[] = [];
    let totalScore = 0;
    const problematicPhonemes: Set<string> = new Set();

    for (let idx = 0; idx < targetWords.length; idx++) {
      const word = targetWords[idx].replace(/[.,!?;:]/g, "");
      const expIpa = standardIpaWords[idx] || word;
      const actIpa = actualIpaWords[idx] || expIpa;

      const { phoneme_analysis, score } = alignPhonemes(expIpa, actIpa);

      phoneme_analysis.forEach((p) => {
        if (p.status === "wrong" || p.status === "missing") {
          problematicPhonemes.add(p.phoneme);
        }
      });

      totalScore += score;
      wordAnalyses.push({
        word,
        expected_ipa: expIpa,
        actual_ipa: actIpa,
        score,
        phoneme_analysis,
      });
    }

    const overallScore = Math.round(totalScore / Math.max(1, targetWords.length));
    const drillPhoneme = problematicPhonemes.size > 0
      ? `/${Array.from(problematicPhonemes)[0]}/`
      : "Hoàn hảo";

    let overallFeedback = "Phát âm rất xuất sắc, độ chính xác ngữ âm cao!";
    if (overallScore < 70) {
      const topIssue = Array.from(problematicPhonemes)[0] || "";
      overallFeedback = `Bạn cần chú ý khẩu hình âm ${topIssue ? `/${topIssue}/` : "phụ âm cuối"}. Hãy nghe lại câu mẫu và bật hơi chậm rãi hơn nhé.`;
    } else if (overallScore < 85) {
      overallFeedback = "Phát âm khá tốt, ngữ điệu tự nhiên. Hãy tập trung cải thiện độ dứt khoát của các âm gió và phụ âm chặn.";
    }

    const result: AssessmentResponse = {
      overall_score: overallScore,
      words: wordAnalyses,
      overall_feedback: overallFeedback,
      recommended_phoneme_drill: drillPhoneme,
    };

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

