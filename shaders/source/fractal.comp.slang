RWTexture2D<float4> image;

[shader("compute")]
[numthreads(16, 16, 1)]
void main(uint3 dispatchThreadID: SV_DispatchThreadID)
{
    uint2 size;
    image.GetDimensions(size.x, size.y);
    int2 texelCoord = int2(dispatchThreadID.xy);

    if (texelCoord.x >= (int)size.x || texelCoord.y >= (int)size.y)
        return;

    // 1. Map pixel coordinates to the Fractal plane (-2.0 to 1.0)
    // This centers the "bug" shape in your texture
    float2 uv = (float2(texelCoord) / float2(size)) * 3.0 - float2(2.1, 1.5);

    float2 z = float2(0.0, 0.0);
    float2 c = uv; // The starting point based on pixel position
    float iterations = 0.0;
    const float maxIterations = 64.0;

    // 2. The Fractal Loop
    // We check: does this point escape to infinity?
    for (float i = 0.0; i < maxIterations; i++)
    {
        // Complex math: z = z^2 + c
        float x = (z.x * z.x - z.y * z.y) + c.x;
        float y = (2.0 * z.x * z.y) + c.y;
        z = float2(x, y);

        if (length(z) > 2.0)
            break;
        iterations++;
    }

    // 3. Coloring based on how long it took to "escape"
    float colorValue = iterations / maxIterations;

    // Create a "Electric Blue" palette
    float3 finalColor = float3(
        pow(colorValue, 3.0), // Red
        pow(colorValue, 1.5), // Green
        colorValue            // Blue
    );

    image[texelCoord] = float4(finalColor, 1.0);
}
