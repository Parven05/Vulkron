RWTexture2D<float4> image;

[shader("compute")]
[numthreads(16, 16, 1)]
void main(uint3 dispatchThreadID: SV_DispatchThreadID)
{
    uint2 size;
    image.GetDimensions(size.x, size.y);
    float2 uv = (float2(dispatchThreadID.xy) / float2(size)) * 2.0 - 1.0;
    uv.x *= float(size.x) / float(size.y);

    // Camera setup
    float3 ro = float3(0, 0, -3);         // Ray Origin
    float3 rd = normalize(float3(uv, 1)); // Ray Direction
    float d = 0;                          // Total distance traveled

    // Simple Raymarching loop
    for (int i = 0; i < 32; i++)
    {
        float3 p = ro + rd * d;
        // Sphere math: length(point) - radius
        // We use frac() to repeat the spheres infinitely
        float sphere = length(frac(p) - 0.5) - 0.25;
        if (sphere < 0.001 || d > 10.0)
            break;
        d += sphere;
    }

    // Shading based on depth
    float col = 1.0 - (d / 10.0);
    image[dispatchThreadID.xy] = float4(col, col * 0.5, col * 0.8, 1.0);
}
