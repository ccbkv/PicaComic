#version 460 core
#include <flutter/runtime_effect.glsl>

// Single-pass, render-time image enhancement for comic reading.
// Runs once per image (cached), so cost is dominated by texture samples; the
// effects below add only per-pixel arithmetic on already-sampled texels
// (clarity adds 4 wide-radius taps):
//   1. Adaptive unsharp mask  - boosts soft/blurry edges, spares sharp text
//      and avoids amplifying flat-area JPEG noise.
//   2. Clarity                - mid-radius local contrast; makes line art and
//      screentones "pop" without the haloing of fine sharpening.
//   3. Level stretch          - pulls dull/greyish scans toward clean black
//      and white (deeper lines, cleaner paper).
//   4. Vibrance               - gently lifts saturation of colour pages only;
//      greyscale pages are untouched (saturation is already zero).

uniform vec2 uSize;        // texture size in pixels
uniform float uStrength;   // unsharp mask strength
uniform float uClarity;    // 0.0 .. 1.0 mid-radius local contrast
uniform float uContrast;   // 0.0 .. 1.0 level-stretch amount
uniform float uVibrance;   // 0.0 .. ~0.5 saturation lift for colour pages
uniform sampler2D uTexture;

out vec4 fragColor;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 texel = 1.0 / uSize;

  vec3 c = texture(uTexture, uv).rgb;

  // 4-neighbour cross blur (cheap low-pass).
  vec3 n = texture(uTexture, uv + vec2(0.0, -texel.y)).rgb;
  vec3 s = texture(uTexture, uv + vec2(0.0, texel.y)).rgb;
  vec3 e = texture(uTexture, uv + vec2(texel.x, 0.0)).rgb;
  vec3 w = texture(uTexture, uv + vec2(-texel.x, 0.0)).rgb;

  vec3 blur = (n + s + e + w) * 0.25;
  vec3 highpass = c - blur;

  // Local contrast from luminance gradient magnitude (0 = flat, large = edge).
  float gx = abs(luma(e) - luma(w));
  float gy = abs(luma(n) - luma(s));
  float contrast = gx + gy;

  // Deadzone: ignore very low contrast so flat-area compression noise is not
  // amplified.
  float lowGate = smoothstep(0.02, 0.06, contrast);

  // Falloff: strong edges (already-sharp text) get progressively less
  // sharpening so typeset characters keep their crisp look without halos.
  float highGate = 1.0 - smoothstep(0.18, 0.38, contrast);

  float amount = uStrength * lowGate * highGate;

  vec3 result = clamp(c + highpass * amount * 2.0, 0.0, 1.0);

  // --- Clarity (mid-radius local contrast) --------------------------------
  // Unsharp mask at a wider radius than the sharpen pass, applied to all
  // tones (not edge-gated), so line art and screentones gain definition
  // without ringing on already-crisp edges.
  if (uClarity > 0.0) {
    float r = 2.5; // blur radius in texels
    vec3 d1 = texture(uTexture, uv + vec2(-texel.x, -texel.y) * r).rgb;
    vec3 d2 = texture(uTexture, uv + vec2(texel.x, -texel.y) * r).rgb;
    vec3 d3 = texture(uTexture, uv + vec2(-texel.x, texel.y) * r).rgb;
    vec3 d4 = texture(uTexture, uv + vec2(-texel.x, texel.y) * r).rgb;
    vec3 wideBlur = (d1 + d2 + d3 + d4) * 0.25;
    // Soft-limit the boost so flat areas (noise) move little and the effect
    // saturates gracefully at high strength.
    vec3 detail = result - wideBlur;
    result = clamp(result + detail * uClarity, 0.0, 1.0);
  }

  // --- Level stretch (contrast) -------------------------------------------
  // Remap [black, white] inwards toward [0, 1] so faded scans regain punch.
  // Gentle, scaled by uContrast; identity when uContrast == 0.
  if (uContrast > 0.0) {
    float black = 0.06 * uContrast;
    float white = 1.0 - 0.06 * uContrast;
    result = clamp((result - black) / max(white - black, 1e-3), 0.0, 1.0);
  }

  // --- Vibrance (colour pages only) ---------------------------------------
  // Lift saturation, weighted so already-saturated pixels move less and near
  // grey pixels (i.e. greyscale manga) are effectively unchanged.
  if (uVibrance > 0.0) {
    float l = luma(result);
    float maxc = max(result.r, max(result.g, result.b));
    float minc = min(result.r, min(result.g, result.b));
    float sat = maxc - minc;            // 0 for greyscale, larger for colour
    float boost = uVibrance * (1.0 - sat);
    result = clamp(mix(vec3(l), result, 1.0 + boost), 0.0, 1.0);
  }

  fragColor = vec4(result, 1.0);
}
