[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputStem,

    [ValidateSet('simple', 'standard', 'fine')]
    [string]$Complexity = 'standard',

    [ValidateSet('strict', 'faithful')]
    [string]$Variant = 'strict',

    [ValidateRange(50, 2000)]
    [double]$LongEdgeMm = 250,

    [ValidateRange(512, 6000)]
    [int]$LongEdgePx = 3000
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input image not found: $InputPath"
}

$minimumBridgeMm = switch ($Complexity) {
    'simple' { 2.5 }
    'standard' { 2.0 }
    'fine' { 1.0 }
}

$minimumOpeningMm = switch ($Complexity) {
    'simple' { 3.0 }
    'standard' { 2.5 }
    'fine' { 1.5 }
}

$outputDirectory = Split-Path -Parent $OutputStem
if ($outputDirectory) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}

Add-Type -AssemblyName System.Drawing

if (-not ('JianzhiRasterProcessor' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

public sealed class JianzhiResult
{
    public string InputPath { get; set; }
    public string PngPath { get; set; }
    public string SvgPath { get; set; }
    public int WorkingWidth { get; set; }
    public int WorkingHeight { get; set; }
    public int PngWidth { get; set; }
    public int PngHeight { get; set; }
    public int ComponentsBefore { get; set; }
    public int ComponentsAfter { get; set; }
    public int BridgesAdded { get; set; }
    public int TinyRedAreasRemoved { get; set; }
    public int TinyWhiteHolesFilled { get; set; }
    public double RedCoveragePercent { get; set; }
    public double LongEdgeMm { get; set; }
    public double MinimumBridgeMm { get; set; }
    public double MinimumOpeningMm { get; set; }
    public string Variant { get; set; }
    public string Status { get; set; }
    public string Recommendation { get; set; }
}

internal sealed class Component
{
    public readonly List<int> Pixels = new List<int>();
    public readonly List<int> Boundary = new List<int>();
}

internal sealed class RectRun
{
    public int X;
    public int Y;
    public int Width;
    public int Height;
}

internal sealed class BoundaryEdge
{
    public int X1;
    public int Y1;
    public int X2;
    public int Y2;
}

public static class JianzhiRasterProcessor
{
    private const int RedR = 217;
    private const int RedG = 56;
    private const int RedB = 30;

    public static JianzhiResult Process(
        string inputPath,
        string outputStem,
        string variant,
        double longEdgeMm,
        int longEdgePx,
        double minimumBridgeMm,
        double minimumOpeningMm)
    {
        string fullInput = Path.GetFullPath(inputPath);
        string pngPath = Path.GetFullPath(outputStem + ".png");
        string svgPath = Path.GetFullPath(outputStem + ".svg");

        using (Bitmap source = new Bitmap(fullInput))
        using (Bitmap working = NormalizeSize(source, 1600))
        {
            int width = working.Width;
            int height = working.Height;
            bool[] mask = ReadBinaryMask(working);
            int minimumRedArea = Math.Max(6, (int)Math.Round(width * height * 0.000008));

            List<Component> initialComponents = FindComponents(mask, width, height, true);
            int removed = RemoveTinyRedComponents(mask, initialComponents, minimumRedArea);
            int openingPx = Math.Max(1, (int)Math.Ceiling(minimumOpeningMm * Math.Max(width, height) / longEdgeMm));
            int filledHoles = FillTinyWhiteHoles(mask, width, height, openingPx);

            List<Component> beforeComponents = FindComponents(mask, width, height, true);
            int componentsBefore = beforeComponents.Count;
            int bridges = 0;

            if (variant.Equals("strict", StringComparison.OrdinalIgnoreCase) && beforeComponents.Count > 1)
            {
                int bridgePx = Math.Max(2, (int)Math.Ceiling(minimumBridgeMm * Math.Max(width, height) / longEdgeMm));
                bridges = ConnectComponents(mask, width, height, beforeComponents, bridgePx);
            }

            List<Component> afterComponents = FindComponents(mask, width, height, true);
            int redPixels = 0;
            for (int i = 0; i < mask.Length; i++) if (mask[i]) redPixels++;

            SaveBinaryPng(mask, width, height, pngPath, longEdgePx);
            SaveSvg(mask, width, height, svgPath, longEdgeMm);

            int pngWidth = width >= height ? longEdgePx : Math.Max(1, (int)Math.Round(longEdgePx * width / (double)height));
            int pngHeight = height >= width ? longEdgePx : Math.Max(1, (int)Math.Round(longEdgePx * height / (double)width));
            bool connected = afterComponents.Count == 1;
            string status = variant.Equals("strict", StringComparison.OrdinalIgnoreCase)
                ? (connected ? "pass" : "fail")
                : (connected ? "pass" : "faithful-multipart");
            bool bridgeWarning = variant.Equals("strict", StringComparison.OrdinalIgnoreCase) && connected && (bridges > 20 || componentsBefore > 40);
            string recommendation = !connected
                ? "Create a strict variant with bridges, enlarge the work, or simplify detached details."
                : (bridgeWarning
                    ? "Structural warning: the master contained many detached red details before repair. Regenerate with fewer independent ornaments, simplify dense areas, or enlarge before calling this final."
                    : "Inspect the narrowest bridges visually at the intended print size before cutting.");

            return new JianzhiResult
            {
                InputPath = fullInput,
                PngPath = pngPath,
                SvgPath = svgPath,
                WorkingWidth = width,
                WorkingHeight = height,
                PngWidth = pngWidth,
                PngHeight = pngHeight,
                ComponentsBefore = componentsBefore,
                ComponentsAfter = afterComponents.Count,
                BridgesAdded = bridges,
                TinyRedAreasRemoved = removed,
                TinyWhiteHolesFilled = filledHoles,
                RedCoveragePercent = Math.Round(100.0 * redPixels / mask.Length, 2),
                LongEdgeMm = longEdgeMm,
                MinimumBridgeMm = minimumBridgeMm,
                MinimumOpeningMm = minimumOpeningMm,
                Variant = variant,
                Status = status,
                Recommendation = recommendation
            };
        }
    }

    private static Bitmap NormalizeSize(Bitmap source, int maximumLongEdge)
    {
        int sourceLongEdge = Math.Max(source.Width, source.Height);
        double scale = sourceLongEdge > maximumLongEdge ? maximumLongEdge / (double)sourceLongEdge : 1.0;
        int width = Math.Max(1, (int)Math.Round(source.Width * scale));
        int height = Math.Max(1, (int)Math.Round(source.Height * scale));
        Bitmap result = new Bitmap(width, height, PixelFormat.Format32bppArgb);
        using (Graphics graphics = Graphics.FromImage(result))
        {
            graphics.Clear(Color.White);
            graphics.CompositingMode = CompositingMode.SourceCopy;
            graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            graphics.DrawImage(source, new Rectangle(0, 0, width, height));
        }
        return result;
    }

    private static bool[] ReadBinaryMask(Bitmap bitmap)
    {
        int width = bitmap.Width;
        int height = bitmap.Height;
        bool[] mask = new bool[width * height];
        Rectangle rectangle = new Rectangle(0, 0, width, height);
        BitmapData data = bitmap.LockBits(rectangle, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try
        {
            int stride = Math.Abs(data.Stride);
            byte[] bytes = new byte[stride * height];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
            for (int y = 0; y < height; y++)
            {
                int row = data.Stride > 0 ? y * stride : (height - 1 - y) * stride;
                for (int x = 0; x < width; x++)
                {
                    int offset = row + x * 4;
                    int b = bytes[offset];
                    int g = bytes[offset + 1];
                    int r = bytes[offset + 2];
                    int redDistance = Square(r - RedR) + Square(g - RedG) + Square(b - RedB);
                    int whiteDistance = Square(r - 255) + Square(g - 255) + Square(b - 255);
                    mask[y * width + x] = redDistance <= whiteDistance;
                }
            }
        }
        finally
        {
            bitmap.UnlockBits(data);
        }
        return mask;
    }

    private static int Square(int value) { return value * value; }

    private static List<Component> FindComponents(bool[] mask, int width, int height, bool target)
    {
        bool[] visited = new bool[mask.Length];
        List<Component> components = new List<Component>();
        int[] queue = new int[mask.Length];
        int[] dx = { 1, -1, 0, 0 };
        int[] dy = { 0, 0, 1, -1 };

        for (int start = 0; start < mask.Length; start++)
        {
            if (visited[start] || mask[start] != target) continue;
            Component component = new Component();
            int head = 0;
            int tail = 0;
            queue[tail++] = start;
            visited[start] = true;

            while (head < tail)
            {
                int index = queue[head++];
                component.Pixels.Add(index);
                int x = index % width;
                int y = index / width;
                bool boundary = false;

                for (int direction = 0; direction < 4; direction++)
                {
                    int nx = x + dx[direction];
                    int ny = y + dy[direction];
                    if (nx < 0 || ny < 0 || nx >= width || ny >= height)
                    {
                        boundary = true;
                        continue;
                    }
                    int neighbor = ny * width + nx;
                    if (mask[neighbor] != target)
                    {
                        boundary = true;
                    }
                    else if (!visited[neighbor])
                    {
                        visited[neighbor] = true;
                        queue[tail++] = neighbor;
                    }
                }

                if (boundary) component.Boundary.Add(index);
            }

            components.Add(component);
        }

        components.Sort((a, b) => b.Pixels.Count.CompareTo(a.Pixels.Count));
        return components;
    }

    private static int RemoveTinyRedComponents(bool[] mask, List<Component> components, int minimumArea)
    {
        int removed = 0;
        foreach (Component component in components)
        {
            if (component.Pixels.Count >= minimumArea) continue;
            foreach (int index in component.Pixels) mask[index] = false;
            removed++;
        }
        return removed;
    }

    private static int FillTinyWhiteHoles(bool[] mask, int width, int height, int openingPx)
    {
        int maximumArea = Math.Max(4, (int)Math.Round(Math.PI * openingPx * openingPx / 4.0));
        int filled = 0;
        foreach (Component component in FindComponents(mask, width, height, false))
        {
            bool touchesBorder = false;
            foreach (int index in component.Boundary)
            {
                int x = index % width;
                int y = index / width;
                if (x == 0 || y == 0 || x == width - 1 || y == height - 1)
                {
                    touchesBorder = true;
                    break;
                }
            }
            if (!touchesBorder && component.Pixels.Count < maximumArea)
            {
                foreach (int index in component.Pixels) mask[index] = true;
                filled++;
            }
        }
        return filled;
    }

    private static int ConnectComponents(bool[] mask, int width, int height, List<Component> components, int bridgeWidth)
    {
        if (components.Count < 2) return 0;
        List<int> mainBoundary = Sample(components[0].Boundary, 2500);
        int bridges = 0;

        for (int componentIndex = 1; componentIndex < components.Count; componentIndex++)
        {
            List<int> islandBoundary = Sample(components[componentIndex].Boundary, 600);
            long bestDistance = long.MaxValue;
            int bestMain = mainBoundary[0];
            int bestIsland = islandBoundary[0];

            foreach (int island in islandBoundary)
            {
                int ix = island % width;
                int iy = island / width;
                foreach (int main in mainBoundary)
                {
                    int mx = main % width;
                    int my = main / width;
                    long dx = ix - mx;
                    long dy = iy - my;
                    long distance = dx * dx + dy * dy;
                    if (distance < bestDistance)
                    {
                        bestDistance = distance;
                        bestMain = main;
                        bestIsland = island;
                    }
                }
            }

            DrawThickLine(mask, width, height,
                bestMain % width, bestMain / width,
                bestIsland % width, bestIsland / width,
                bridgeWidth);
            bridges++;
        }
        return bridges;
    }

    private static List<int> Sample(List<int> source, int maximum)
    {
        if (source.Count <= maximum) return source;
        List<int> result = new List<int>(maximum);
        double step = source.Count / (double)maximum;
        for (int i = 0; i < maximum; i++) result.Add(source[(int)Math.Floor(i * step)]);
        return result;
    }

    private static void DrawThickLine(bool[] mask, int width, int height, int x0, int y0, int x1, int y1, int lineWidth)
    {
        int dx = Math.Abs(x1 - x0);
        int sx = x0 < x1 ? 1 : -1;
        int dy = -Math.Abs(y1 - y0);
        int sy = y0 < y1 ? 1 : -1;
        int error = dx + dy;
        int radius = Math.Max(1, lineWidth / 2);

        while (true)
        {
            PaintDisk(mask, width, height, x0, y0, radius);
            if (x0 == x1 && y0 == y1) break;
            int doubled = 2 * error;
            if (doubled >= dy) { error += dy; x0 += sx; }
            if (doubled <= dx) { error += dx; y0 += sy; }
        }
    }

    private static void PaintDisk(bool[] mask, int width, int height, int centerX, int centerY, int radius)
    {
        int radiusSquared = radius * radius;
        for (int y = Math.Max(0, centerY - radius); y <= Math.Min(height - 1, centerY + radius); y++)
        {
            for (int x = Math.Max(0, centerX - radius); x <= Math.Min(width - 1, centerX + radius); x++)
            {
                int dx = x - centerX;
                int dy = y - centerY;
                if (dx * dx + dy * dy <= radiusSquared) mask[y * width + x] = true;
            }
        }
    }

    private static void SaveBinaryPng(bool[] mask, int width, int height, string path, int longEdgePx)
    {
        int outputWidth = width >= height ? longEdgePx : Math.Max(1, (int)Math.Round(longEdgePx * width / (double)height));
        int outputHeight = height >= width ? longEdgePx : Math.Max(1, (int)Math.Round(longEdgePx * height / (double)width));
        List<List<PointF>> loops = BuildBoundaryLoops(mask, width, height, 1.15);

        using (Bitmap output = new Bitmap(outputWidth, outputHeight, PixelFormat.Format32bppArgb))
        using (Graphics graphics = Graphics.FromImage(output))
        using (Brush redBrush = new SolidBrush(Color.FromArgb(255, RedR, RedG, RedB)))
        using (GraphicsPath pathData = BuildGraphicsPath(loops, outputWidth / (float)width, outputHeight / (float)height))
        {
            graphics.Clear(Color.White);
            graphics.SmoothingMode = SmoothingMode.AntiAlias;
            graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            graphics.FillPath(redBrush, pathData);
            output.Save(path, ImageFormat.Png);
        }
    }

    private static void SaveSvg(bool[] mask, int width, int height, string path, double longEdgeMm)
    {
        List<List<PointF>> loops = BuildBoundaryLoops(mask, width, height, 1.15);
        StringBuilder pathData = BuildSvgPathData(loops);

        double widthMm = width >= height ? longEdgeMm : longEdgeMm * width / height;
        double heightMm = height >= width ? longEdgeMm : longEdgeMm * height / width;
        string widthText = widthMm.ToString("0.###", CultureInfo.InvariantCulture);
        string heightText = heightMm.ToString("0.###", CultureInfo.InvariantCulture);
        string svg = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" + widthText + "mm\" height=\"" + heightText +
            "mm\" viewBox=\"0 0 " + width + " " + height + "\">\n" +
            "  <rect width=\"100%\" height=\"100%\" fill=\"#FFFFFF\"/>\n" +
            "  <path fill=\"#D9381E\" fill-rule=\"evenodd\" shape-rendering=\"geometricPrecision\" d=\"" + pathData + "\"/>\n" +
            "</svg>\n";
        File.WriteAllText(path, svg, new UTF8Encoding(false));
    }

    private static GraphicsPath BuildGraphicsPath(List<List<PointF>> loops, float scaleX, float scaleY)
    {
        GraphicsPath result = new GraphicsPath(FillMode.Alternate);
        foreach (List<PointF> loop in loops)
        {
            if (loop.Count < 3) continue;
            PointF[] scaled = new PointF[loop.Count];
            for (int i = 0; i < loop.Count; i++)
            {
                scaled[i] = new PointF(loop[i].X * scaleX, loop[i].Y * scaleY);
            }
            result.AddPolygon(scaled);
        }
        return result;
    }

    private static StringBuilder BuildSvgPathData(List<List<PointF>> loops)
    {
        StringBuilder pathData = new StringBuilder(loops.Count * 128);
        foreach (List<PointF> loop in loops)
        {
            if (loop.Count < 3) continue;
            if (loop.Count < 8)
            {
                pathData.Append('M').Append(Format(loop[0].X)).Append(' ').Append(Format(loop[0].Y));
                for (int i = 1; i < loop.Count; i++)
                {
                    pathData.Append('L').Append(Format(loop[i].X)).Append(' ').Append(Format(loop[i].Y));
                }
                pathData.Append('z');
                continue;
            }

            PointF start = Midpoint(loop[0], loop[1]);
            pathData.Append('M').Append(Format(start.X)).Append(' ').Append(Format(start.Y));
            for (int i = 1; i <= loop.Count; i++)
            {
                PointF control = loop[i % loop.Count];
                PointF next = loop[(i + 1) % loop.Count];
                PointF end = Midpoint(control, next);
                pathData.Append('Q').Append(Format(control.X)).Append(' ').Append(Format(control.Y))
                    .Append(' ').Append(Format(end.X)).Append(' ').Append(Format(end.Y));
            }
            pathData.Append('z');
        }
        return pathData;
    }

    private static List<List<PointF>> BuildBoundaryLoops(bool[] mask, int width, int height, double tolerance)
    {
        Dictionary<string, List<BoundaryEdge>> starts = new Dictionary<string, List<BoundaryEdge>>();
        int edgeCount = 0;

        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
                if (!mask[y * width + x]) continue;
                if (y == 0 || !mask[(y - 1) * width + x])
                {
                    AddEdge(starts, new BoundaryEdge { X1 = x, Y1 = y, X2 = x + 1, Y2 = y });
                    edgeCount++;
                }
                if (x == width - 1 || !mask[y * width + x + 1])
                {
                    AddEdge(starts, new BoundaryEdge { X1 = x + 1, Y1 = y, X2 = x + 1, Y2 = y + 1 });
                    edgeCount++;
                }
                if (y == height - 1 || !mask[(y + 1) * width + x])
                {
                    AddEdge(starts, new BoundaryEdge { X1 = x + 1, Y1 = y + 1, X2 = x, Y2 = y + 1 });
                    edgeCount++;
                }
                if (x == 0 || !mask[y * width + x - 1])
                {
                    AddEdge(starts, new BoundaryEdge { X1 = x, Y1 = y + 1, X2 = x, Y2 = y });
                    edgeCount++;
                }
            }
        }

        List<List<PointF>> loops = new List<List<PointF>>();
        while (edgeCount > 0)
        {
            BoundaryEdge first = PopAnyEdge(starts);
            if (first == null) break;
            edgeCount--;

            List<PointF> loop = new List<PointF>();
            loop.Add(new PointF(first.X1, first.Y1));
            loop.Add(new PointF(first.X2, first.Y2));

            int startX = first.X1;
            int startY = first.Y1;
            int currentX = first.X2;
            int currentY = first.Y2;
            int guard = Math.Max(16, edgeCount + 16);

            while (!(currentX == startX && currentY == startY) && guard-- > 0)
            {
                BoundaryEdge next = PopEdgeStartingAt(starts, currentX, currentY);
                if (next == null) break;
                edgeCount--;
                currentX = next.X2;
                currentY = next.Y2;
                loop.Add(new PointF(currentX, currentY));
            }

            if (loop.Count > 3)
            {
                RemoveDuplicateClosingPoint(loop);
                loop = SimplifyClosedLoop(loop, tolerance);
                if (loop.Count > 2) loops.Add(loop);
            }
        }

        return loops;
    }

    private static void AddEdge(Dictionary<string, List<BoundaryEdge>> starts, BoundaryEdge edge)
    {
        string key = Key(edge.X1, edge.Y1);
        List<BoundaryEdge> edges;
        if (!starts.TryGetValue(key, out edges))
        {
            edges = new List<BoundaryEdge>();
            starts[key] = edges;
        }
        edges.Add(edge);
    }

    private static BoundaryEdge PopAnyEdge(Dictionary<string, List<BoundaryEdge>> starts)
    {
        foreach (string key in new List<string>(starts.Keys))
        {
            List<BoundaryEdge> edges = starts[key];
            if (edges.Count == 0)
            {
                starts.Remove(key);
                continue;
            }
            BoundaryEdge result = edges[edges.Count - 1];
            edges.RemoveAt(edges.Count - 1);
            if (edges.Count == 0) starts.Remove(key);
            return result;
        }
        return null;
    }

    private static BoundaryEdge PopEdgeStartingAt(Dictionary<string, List<BoundaryEdge>> starts, int x, int y)
    {
        string key = Key(x, y);
        List<BoundaryEdge> edges;
        if (!starts.TryGetValue(key, out edges) || edges.Count == 0) return null;
        BoundaryEdge result = edges[edges.Count - 1];
        edges.RemoveAt(edges.Count - 1);
        if (edges.Count == 0) starts.Remove(key);
        return result;
    }

    private static string Key(int x, int y)
    {
        return x.ToString(CultureInfo.InvariantCulture) + "," + y.ToString(CultureInfo.InvariantCulture);
    }

    private static void RemoveDuplicateClosingPoint(List<PointF> points)
    {
        if (points.Count < 2) return;
        PointF first = points[0];
        PointF last = points[points.Count - 1];
        if (Math.Abs(first.X - last.X) < 0.001 && Math.Abs(first.Y - last.Y) < 0.001)
        {
            points.RemoveAt(points.Count - 1);
        }
    }

    private static List<PointF> SimplifyClosedLoop(List<PointF> points, double tolerance)
    {
        if (points.Count < 4) return points;
        List<PointF> closed = new List<PointF>(points);
        closed.Add(points[0]);
        List<PointF> simplified = SimplifyOpenPolyline(closed, tolerance);
        RemoveDuplicateClosingPoint(simplified);
        return simplified;
    }

    private static List<PointF> SimplifyOpenPolyline(List<PointF> points, double tolerance)
    {
        if (points.Count <= 2) return new List<PointF>(points);
        bool[] keep = new bool[points.Count];
        keep[0] = true;
        keep[points.Count - 1] = true;
        SimplifySection(points, 0, points.Count - 1, tolerance * tolerance, keep);

        List<PointF> result = new List<PointF>();
        for (int i = 0; i < points.Count; i++)
        {
            if (keep[i]) result.Add(points[i]);
        }
        return result;
    }

    private static void SimplifySection(List<PointF> points, int first, int last, double toleranceSquared, bool[] keep)
    {
        if (last <= first + 1) return;
        double bestDistance = -1;
        int bestIndex = -1;
        for (int i = first + 1; i < last; i++)
        {
            double distance = DistanceToSegmentSquared(points[i], points[first], points[last]);
            if (distance > bestDistance)
            {
                bestDistance = distance;
                bestIndex = i;
            }
        }
        if (bestDistance > toleranceSquared && bestIndex >= 0)
        {
            keep[bestIndex] = true;
            SimplifySection(points, first, bestIndex, toleranceSquared, keep);
            SimplifySection(points, bestIndex, last, toleranceSquared, keep);
        }
    }

    private static double DistanceToSegmentSquared(PointF point, PointF start, PointF end)
    {
        double dx = end.X - start.X;
        double dy = end.Y - start.Y;
        if (Math.Abs(dx) < 0.0001 && Math.Abs(dy) < 0.0001)
        {
            double px = point.X - start.X;
            double py = point.Y - start.Y;
            return px * px + py * py;
        }
        double t = ((point.X - start.X) * dx + (point.Y - start.Y) * dy) / (dx * dx + dy * dy);
        if (t < 0) t = 0;
        if (t > 1) t = 1;
        double projectionX = start.X + t * dx;
        double projectionY = start.Y + t * dy;
        double diffX = point.X - projectionX;
        double diffY = point.Y - projectionY;
        return diffX * diffX + diffY * diffY;
    }

    private static PointF Midpoint(PointF a, PointF b)
    {
        return new PointF((a.X + b.X) * 0.5f, (a.Y + b.Y) * 0.5f);
    }

    private static string Format(float value)
    {
        return value.ToString("0.##", CultureInfo.InvariantCulture);
    }

    private static List<RectRun> MergeRuns(bool[] mask, int width, int height)
    {
        Dictionary<string, RectRun> active = new Dictionary<string, RectRun>();
        List<RectRun> complete = new List<RectRun>();

        for (int y = 0; y < height; y++)
        {
            Dictionary<string, RectRun> next = new Dictionary<string, RectRun>();
            int x = 0;
            while (x < width)
            {
                while (x < width && !mask[y * width + x]) x++;
                if (x >= width) break;
                int start = x;
                while (x < width && mask[y * width + x]) x++;
                int runWidth = x - start;
                string key = start.ToString(CultureInfo.InvariantCulture) + ":" + runWidth.ToString(CultureInfo.InvariantCulture);
                RectRun rectangle;
                if (active.TryGetValue(key, out rectangle))
                {
                    rectangle.Height++;
                    active.Remove(key);
                }
                else
                {
                    rectangle = new RectRun { X = start, Y = y, Width = runWidth, Height = 1 };
                }
                next[key] = rectangle;
            }

            foreach (RectRun rectangle in active.Values) complete.Add(rectangle);
            active = next;
        }

        foreach (RectRun rectangle in active.Values) complete.Add(rectangle);
        return complete;
    }
}
'@
}

$result = [JianzhiRasterProcessor]::Process(
    (Resolve-Path -LiteralPath $InputPath).Path,
    $OutputStem,
    $Variant,
    $LongEdgeMm,
    $LongEdgePx,
    $minimumBridgeMm,
    $minimumOpeningMm
)

$reportPath = "$OutputStem.report.json"
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8
$result | ConvertTo-Json -Depth 4
