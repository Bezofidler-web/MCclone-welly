// SPDX-License-Identifier: GPL-3.0-or-later
// Final colour pass for Mineclonia's Basic profile (Luanti 5.18).

uniform sampler2D texture0; // Scene colour, in display space.
#ifdef ENABLE_BLOOM
uniform sampler2D texture1; // Blurred scene, in linear space.
uniform lowp float bloomIntensity;
#endif
uniform vec2 texelSize0;
uniform lowp float saturation;

struct ExposureParams {
	float compensationFactor;
};
uniform ExposureParams exposureParams;

CENTROID_ VARYING_ mediump vec2 varTexCoord;
#ifdef ENABLE_AUTO_EXPOSURE
VARYING_ float exposure;
#endif

vec3 readScene(vec2 uv)
{
#ifdef ENABLE_SSAA
	vec3 sum = vec3(0.0);
	for (float y = 1.0; y < SSAA_SCALE; y += 2.0)
		for (float x = 1.0; x < SSAA_SCALE; x += 2.0)
			sum += texture2D(texture0, uv + texelSize0 * vec2(x, y)).rgb;
	return sum * (4.0 / (SSAA_SCALE * SSAA_SCALE));
#else
	return texture2D(texture0, uv).rgb;
#endif
}

vec3 gradeColour(vec3 colour)
{
	const vec3 luminanceWeights = vec3(0.2126, 0.7152, 0.0722);
	float luminance = dot(colour, luminanceWeights);

	// Grade the midtones. Fade the tint near black and white so dark caves
	// stay legible and bright snow and clouds retain neutral highlights.
	float shadows = smoothstep(0.02, 0.22, luminance)
		* (1.0 - smoothstep(0.24, 0.56, luminance));
	float sunlight = smoothstep(0.35, 0.76, luminance)
		* (1.0 - smoothstep(0.82, 1.0, luminance));
	colour *= vec3(1.0) + vec3(-0.065, 0.008, 0.12) * shadows
		+ vec3(0.06, 0.025, -0.09) * sunlight;

	// Boost muted surfaces more than already colourful foliage and skies.
	float chroma = max(max(colour.r, colour.g), colour.b)
		- min(min(colour.r, colour.g), colour.b);
	float vibrance = 1.0 + 0.18 * (1.0 - smoothstep(0.10, 0.65, chroma));
	luminance = dot(colour, luminanceWeights);
	colour = mix(vec3(luminance), colour, saturation * vibrance);

	// A soft shoulder saves headroom for bloom and warmth in highlights.
	colour = max(colour, vec3(0.0));
	vec3 highlights = max(colour - vec3(0.76), vec3(0.0));
	return colour - highlights + highlights / (1.0 + 0.36 * highlights);
}

void main()
{
	vec2 uv = varTexCoord;
	vec3 scene = readScene(uv);
	vec3 light = pow(max(scene, vec3(0.0)), vec3(2.2));
	light *= exposureParams.compensationFactor;
#ifdef ENABLE_AUTO_EXPOSURE
	light *= exposure;
#endif
#ifdef ENABLE_BLOOM
	vec3 glow = texture2D(texture1, uv).rgb;
#ifdef ENABLE_BLOOM_DEBUG
	if (uv.x > 0.5 && uv.y < 0.5) {
		gl_FragColor = vec4(pow(max(glow, vec3(0.0)), vec3(1.0 / 2.2)), 1.0);
		return;
	}
	if (uv.x < 0.5) {
		gl_FragColor = vec4(scene, 1.0);
		return;
	}
#endif
	light = mix(light, glow, bloomIntensity);
#endif

#if ENABLE_TONE_MAPPING
	// Optional highlight compression with a linear response in darker areas.
	vec3 excess = max(light - vec3(0.38), vec3(0.0));
	light -= excess * excess / (1.0 + excess);
#endif

	vec3 colour = gradeColour(pow(max(light, vec3(0.0)), vec3(1.0 / 2.2)));
#if defined(ENABLE_DITHERING) && (!defined(GL_ES) || defined(GL_FRAGMENT_PRECISION_HIGH))
	highp float noise = fract(dot(gl_FragCoord.xy, vec2(0.7548777, 0.5698403)));
	colour += vec3((noise - 0.5) / 255.0);
#endif
	gl_FragColor = vec4(clamp(colour, 0.0, 1.0), 1.0);
}
