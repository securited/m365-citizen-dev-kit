param([int]$Port = 7432, [string]$Root = "$PSScriptRoot\..")

$Root = (Resolve-Path $Root).Path
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $Root on http://localhost:$Port/"

$mime = @{
  '.html' = 'text/html'; '.htm' = 'text/html'
  '.css'  = 'text/css';  '.js'  = 'text/javascript'
  '.json' = 'application/json'; '.md' = 'text/plain'
  '.aspx' = 'text/html'
  '.png'  = 'image/png'; '.svg' = 'image/svg+xml'
}

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $rel = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
  if (-not $rel) { $rel = 'index.html' }
  $path = Join-Path $Root $rel
  try {
    if ((Test-Path $path -PathType Leaf) -and ((Resolve-Path $path).Path.StartsWith($Root))) {
      $bytes = [System.IO.File]::ReadAllBytes($path)
      $ext = [System.IO.Path]::GetExtension($path).ToLower()
      $ctx.Response.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $ctx.Response.StatusCode = 404
    }
  } catch {
    $ctx.Response.StatusCode = 500
  }
  $ctx.Response.Close()
}
