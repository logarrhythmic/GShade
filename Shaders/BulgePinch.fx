/*-----------------------------------------------------------------------------------------------------*/
/* PBDistort Shader v5.0 - by Radegast Stravinsky of Ultros.                                               */
/* There are plenty of shaders that make your game look amazing. This isn't one of them.               */
/*-----------------------------------------------------------------------------------------------------*/
#include "ReShade.fxh"
#include "Blending.fxh"
#include "TriDither.fxh"

uniform float radius <
    ui_type = "slider";
    ui_label = "Radius";
    ui_tooltip = "The radius of the distortion.";
    ui_min = 0.0; 
    ui_max = 1.0;
> = 0.5;

uniform float magnitude <
    ui_type = "slider";
    ui_label = "Magnitude";
    ui_tooltip = "The magnitude of the distortion. Positive values cause the image to bulge out. Negative values cause the image to pinch in.";
    ui_min = -1.0; 
    ui_max = 1.0;
> = -0.5;

uniform float tension <
    ui_type = "slider";
    ui_label = "Tension";
    ui_tooltip = "Adjusts how rapidly the image reaches the maximum distortion from the edge to the center.";
    ui_min = 0.; 
    ui_max = 10.; 
    ui_step = 0.001;
> = 1.0;

uniform float2 coordinates <
    ui_type = "slider";
    ui_label="Coordinates";
    ui_tooltip="The X and Y position of the center of the effect.";
    ui_min = 0.0; ui_max = 1.0;
> = 0.25;

uniform bool use_mouse_point <
    ui_label="Use Mouse Coordinates";
    ui_tooltip="When enabled, uses the mouse's current coordinates instead of those defined by the Coordinates sliders";
> = false;

uniform float min_depth <
    ui_type = "slider";
    ui_label="Minimum Depth";
    ui_min=0.0;
    ui_max=1.0;
> = 0;

uniform float aspect_ratio <
    ui_type = "slider";
    ui_label = "Aspect Ratio"; 
    ui_min = -100.0; 
    ui_max = 100.0;
> = 0;

uniform int animate <
    ui_type = "combo";
    ui_label = "Animate";
    ui_items = "No\0Yes\0";
    ui_tooltip = "Animates the effect.";
> = 0;

BLENDING_COMBO(
    render_type, 
    "Blending Mode", 
    "Blends the effect with the previous layers.",
    "Blending",
    false,
    0,
    0
);

uniform float anim_rate <
    source = "timer";
>;

uniform float2 mouse_coordinates < 
source= "mousepoint";
>;

texture texColorBuffer : COLOR;

sampler samplerColor
{
    Texture = texColorBuffer;

    AddressU = MIRROR;
    AddressV = MIRROR;
    AddressW = MIRROR;

    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;

    MinLOD = 0.0f;
    MaxLOD = 1000.0f;

    MipLODBias = 0.0f;

    SRGBTexture = false;
};

// Vertex Shader
void FullScreenVS(uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD0)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    
    position = float4( texcoord * float2(2, -2) + float2(-1, 1), 0, 1);
    //position /= BUFFER_HEIGHT/BUFFER_WIDTH;

}

// Pixel Shaders (in order of appearance in the technique)
float4 PBDistort(float4 pos : SV_Position, float2 texcoord : TEXCOORD0) : SV_TARGET
{
    const float ar_raw = 1.0 * (float)BUFFER_HEIGHT / (float)BUFFER_WIDTH;
    float ar = lerp(ar_raw, 1, aspect_ratio * 0.01);

    float2 center = coordinates;
    if (use_mouse_point) 
        center = float2(mouse_coordinates.x * BUFFER_RCP_WIDTH / 2.0, mouse_coordinates.y * BUFFER_RCP_HEIGHT / 2.0);

    float2 tc = texcoord - center;

    float4 color;
    const float4 base = tex2D(samplerColor, texcoord);
    const float depth = ReShade::GetLinearizedDepth(texcoord).r;

    center.x /= ar;
    tc.x /= ar;

    float dist = distance(tc, center);
    if (dist < radius && depth >= min_depth)
    {
        float anim_mag = (animate == 1 ? magnitude * sin(radians(anim_rate * 0.05)) : magnitude);
        float tension_radius = lerp(dist, radius, tension);
        float percent = (dist)/tension_radius;
        if(anim_mag > 0)
            tc = (tc-center) * lerp(1.0, smoothstep(0.0, radius/dist, percent), anim_mag * 0.75);
        else
            tc = (tc-center) * lerp(1.0, pow(abs(percent), 1.0 + anim_mag * 0.75) * radius/dist, 1.0 - percent);

        tc += (2*center);
        tc.x *= ar;

        color = tex2D(samplerColor, tc);
        if(render_type)
            color.rgb = ComHeaders::Blending::Blend(render_type, base.rgb, color.rgb, 1 - percent);
    }
    else {
        color = tex2D(samplerColor, texcoord);
    }



#if GSHADE_DITHER
	return float4(color.rgb + TriDither(color.rgb, texcoord, BUFFER_COLOR_BIT_DEPTH), color.a);
#else
    return color;
#endif
}

// Technique
technique BulgePinch < ui_label="Bulge/Pinch";>
{
    pass p0
    {
        VertexShader = FullScreenVS;
        PixelShader = PBDistort;
    }
};
