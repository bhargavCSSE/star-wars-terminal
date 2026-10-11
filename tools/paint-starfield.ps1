# Paints the terminal background: Catppuccin Mocha starfield with an X-wing (2560x1600).
# Needs Windows PowerShell (System.Drawing). Usage: powershell -File tools\paint-starfield.ps1
# The X-wing angle is set by $roll, $yaw and $pitch in the ship section below.
param([string] $Out = (Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\starfield.png'))
Add-Type -AssemblyName System.Drawing
$W = 2560; $H = 1600
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
function C([int]$a, [int]$hex) { [System.Drawing.Color]::FromArgb($a, ($hex -shr 16) -band 255, ($hex -shr 8) -band 255, $hex -band 255) }
function P([double]$x, [double]$y) { New-Object System.Drawing.PointF ([single]$x), ([single]$y) }
$g.Clear((C 255 0x1E1E2E))
$rand = New-Object System.Random 1977

function Glow([double]$cx, [double]$cy, [double]$r, [int]$hex, [int]$alpha) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse([single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r))
  $brush = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
  $brush.CenterColor = C $alpha $hex
  $brush.SurroundColors = [System.Drawing.Color[]]@(C 0 $hex)
  $g.FillPath($brush, $path); $brush.Dispose(); $path.Dispose()
}

# Faint nebula on the right, away from where most text sits
Glow 2050 380 620 0xCBA6F7 26
Glow 1750 620 520 0x89B4FA 18
Glow 2300 760 420 0xF5C2E7 12
Glow 1450 300 380 0xB4BEFE 10

# A wispy galactic band running diagonally, with extra faint stars along it
function Jitter([double]$spread) { ($rand.NextDouble() + $rand.NextDouble() + $rand.NextDouble() - 1.5) * $spread }
for ($i = 0; $i -lt 160; $i++) {
  $t = $rand.NextDouble(); $x = 300 + $t * 2200 + (Jitter 120); $y = 1350 - $t * 1150 + (Jitter 260)
  Glow $x $y (40 + $rand.NextDouble() * 110) 0xB4BEFE (3 + $rand.Next(4))
}
for ($i = 0; $i -lt 1100; $i++) {
  $t = $rand.NextDouble(); $x = 300 + $t * 2200 + (Jitter 100); $y = 1350 - $t * 1150 + (Jitter 200)
  $s = 0.8 + $rand.NextDouble() * 0.9
  $b = New-Object System.Drawing.SolidBrush (C (35 + $rand.Next(70)) 0xCDD6F4)
  $g.FillEllipse($b, [single]($x - $s / 2), [single]($y - $s / 2), [single]$s, [single]$s); $b.Dispose()
}

# Stars: mostly dim pinpoints, a few brighter ones with a soft halo
$tints = 0xCDD6F4, 0xCDD6F4, 0xCDD6F4, 0xB4BEFE, 0xF5E0DC, 0x89DCEB
for ($i = 0; $i -lt 1700; $i++) {
  $x = $rand.NextDouble() * $W; $y = $rand.NextDouble() * $H
  $roll = $rand.NextDouble(); $tint = $tints[$rand.Next($tints.Count)]
  if ($roll -lt 0.85) { $size = 1.0 + $rand.NextDouble() * 1.2; $a = 50 + $rand.Next(80) }
  elseif ($roll -lt 0.98) { $size = 1.8 + $rand.NextDouble() * 1.2; $a = 130 + $rand.Next(70) }
  else { $size = 2.6 + $rand.NextDouble() * 1.2; $a = 220; Glow $x $y (9 + $rand.NextDouble() * 8) $tint 60 }
  $b = New-Object System.Drawing.SolidBrush (C $a $tint)
  $g.FillEllipse($b, [single]($x - $size / 2), [single]($y - $size / 2), [single]$size, [single]$size); $b.Dispose()
}

# X-wing in a three-quarter front view: a small 3D model, lit and drawn back to front.
# Ship space: x = starboard, y = up, z = forward (toward the nose).
$CX = 2140.0; $CY = 1300.0; $K = 46.0; $D = 60.0       # screen anchor, pixels per unit, camera distance
$roll = -6.0; $yaw = -155.0; $pitch = 14.0             # bank, seen from behind with the nose turned a little to the left, from slightly above
$light = [double[]]@(-0.45, 0.75, 0.5); $ll = [math]::Sqrt(($light | ForEach-Object { $_ * $_ } | Measure-Object -Sum).Sum)
$light = [double[]]@(($light[0] / $ll), ($light[1] / $ll), ($light[2] / $ll))

function Xf([double[]]$v) {
  $a = $roll * [math]::PI / 180; $x1 = $v[0] * [math]::Cos($a) - $v[1] * [math]::Sin($a); $y1 = $v[0] * [math]::Sin($a) + $v[1] * [math]::Cos($a); $z1 = $v[2]
  $b = $yaw * [math]::PI / 180; $x2 = $x1 * [math]::Cos($b) + $z1 * [math]::Sin($b); $z2 = -$x1 * [math]::Sin($b) + $z1 * [math]::Cos($b)
  $c = $pitch * [math]::PI / 180; $y3 = $y1 * [math]::Cos($c) - $z2 * [math]::Sin($c); $z3 = $y1 * [math]::Sin($c) + $z2 * [math]::Cos($c)
  , ([double[]]@($x2, $y3, $z3))
}
function Proj([double[]]$t) { $p = $D / ($D - $t[2]); P ($CX + $t[0] * $K * $p) ($CY - $t[1] * $K * $p) }
function Shade([int]$hex, [double]$f) {
  $r = [math]::Min(255, [int]((($hex -shr 16) -band 255) * $f)); $gg = [math]::Min(255, [int]((($hex -shr 8) -band 255) * $f)); $bb = [math]::Min(255, [int](($hex -band 255) * $f))
  [System.Drawing.Color]::FromArgb(255, $r, $gg, $bb)
}

$items = New-Object System.Collections.ArrayList
# verts: ship-space points; center: a point inside the solid (to orient normals outward)
function Face($verts, [int]$hex, [double[]]$center, [switch]$TwoSided, [switch]$Glowing, [double]$Bias = 0, [double]$Depth = [double]::NaN) {
  $t = foreach ($v in $verts) { Xf $v }
  $c = [double[]]@(0, 0, 0); foreach ($q in $t) { $c[0] += $q[0] / $t.Count; $c[1] += $q[1] / $t.Count; $c[2] += $q[2] / $t.Count }
  $u = [double[]]@(($t[1][0] - $t[0][0]), ($t[1][1] - $t[0][1]), ($t[1][2] - $t[0][2]))
  $w = [double[]]@(($t[2][0] - $t[0][0]), ($t[2][1] - $t[0][1]), ($t[2][2] - $t[0][2]))
  $n = [double[]]@(($u[1] * $w[2] - $u[2] * $w[1]), ($u[2] * $w[0] - $u[0] * $w[2]), ($u[0] * $w[1] - $u[1] * $w[0]))
  $len = [math]::Sqrt($n[0] * $n[0] + $n[1] * $n[1] + $n[2] * $n[2]); if ($len -lt 1e-9) { return }
  $n = [double[]]@(($n[0] / $len), ($n[1] / $len), ($n[2] / $len))
  $toCam = [double[]]@((-$c[0]), (-$c[1]), ($D - $c[2]))
  if ($TwoSided) { if (($n[0] * $toCam[0] + $n[1] * $toCam[1] + $n[2] * $toCam[2]) -lt 0) { $n = [double[]]@((-$n[0]), (-$n[1]), (-$n[2])) } }
  else {
    $sc = Xf $center
    if (($n[0] * ($c[0] - $sc[0]) + $n[1] * ($c[1] - $sc[1]) + $n[2] * ($c[2] - $sc[2])) -lt 0) { $n = [double[]]@((-$n[0]), (-$n[1]), (-$n[2])) }
    if (($n[0] * $toCam[0] + $n[1] * $toCam[1] + $n[2] * $toCam[2]) -le 0) { return }   # faces away from us
  }
  $lam = [math]::Max(0, $n[0] * $light[0] + $n[1] * $light[1] + $n[2] * $light[2])
  $col = if ($Glowing) { Shade $hex 1.0 } else { Shade $hex (0.38 + 0.6 * $lam) }
  $pts = [System.Drawing.PointF[]]@(foreach ($q in $t) { Proj $q })
  $dep = if ([double]::IsNaN($Depth)) { $c[2] + $Bias } else { $Depth }
  [void]$items.Add([pscustomobject]@{ Depth = $dep; Pts = $pts; Color = $col })
}
# ring of points around the z axis: rectangle (n = 4) or ellipse
function Ring([double]$cx, [double]$cy, [double]$z, [double]$w, [double]$h, [int]$n) {
  if ($n -eq 4) { return , @([double[]]@(($cx + $w), ($cy + $h), $z), [double[]]@(($cx - $w), ($cy + $h), $z), [double[]]@(($cx - $w), ($cy - $h), $z), [double[]]@(($cx + $w), ($cy - $h), $z)) }
  , @(for ($i = 0; $i -lt $n; $i++) { $a = 2 * [math]::PI * $i / $n; , [double[]]@(($cx + $w * [math]::Cos($a)), ($cy + $h * [math]::Sin($a)), $z) })
}
# solid between two rings (back ring a, front ring b), with end caps
function Loft($a, $b, [int]$hex, [int]$backHex, [int]$frontHex, [switch]$GlowBack) {
  $all = @($a) + @($b); $ctr = [double[]]@(0, 0, 0)
  foreach ($q in $all) { $ctr[0] += $q[0] / $all.Count; $ctr[1] += $q[1] / $all.Count; $ctr[2] += $q[2] / $all.Count }
  for ($i = 0; $i -lt $a.Count; $i++) { $j = ($i + 1) % $a.Count; Face @($a[$i], $a[$j], $b[$j], $b[$i]) $hex $ctr }
  Face $a $backHex $ctr -Glowing:$GlowBack
  Face $b $frontHex $ctr
}

$hullHex = 0x5C6079; $wingHex = 0x62667F; $darkHex = 0x16161F; $glassHex = 0x3B4C72; $stripeHex = 0x9A5E74; $exhaustHex = 0x26273A

# fuselage: rear block and tapered nose
Loft (Ring 0 0 -5.0 0.62 0.60 4) (Ring 0 0 1.6 0.62 0.60 4) $hullHex $hullHex $hullHex
Loft (Ring 0 0 1.6 0.60 0.58 4) (Ring 0 -0.12 7.4 0.22 0.20 4) $hullHex $hullHex $hullHex
# cockpit canopy: sloped glass on top, ahead of the wings
Loft (Ring 0 0.80 -0.8 0.42 0.20 4) (Ring 0 0.66 2.0 0.30 0.06 4) $glassHex $glassHex $glassHex

# wings in attack position, engines at the roots, cannons at the tips
$foil = 13.0 * [math]::PI / 180
foreach ($sx in 1, -1) { foreach ($sy in 1, -1) {
  $dx = $sx * [math]::Cos($foil); $dy = $sy * [math]::Sin($foil)
  $at = { param($r, $z) [double[]]@(($dx * $r), ($dy * $r), $z) }
  $wing = @((& $at 0.6 -1.9), (& $at 5.6 -2.9), (& $at 5.6 -4.2), (& $at 0.6 -4.6))
  Face $wing $wingHex $null -TwoSided; $wingDepth = $items[$items.Count - 1].Depth
  # Red Squadron stripe across the wing, drawn just in front of it
  $f0 = (2.0 - 0.6) / 5.0; $f1 = (2.7 - 0.6) / 5.0
  $lead0 = -1.9 + (-2.9 + 1.9) * $f0; $lead1 = -1.9 + (-2.9 + 1.9) * $f1; $trail0 = -4.6 + (-4.2 + 4.6) * $f0; $trail1 = -4.6 + (-4.2 + 4.6) * $f1
  Face @((& $at 2.0 $lead0), (& $at 2.7 $lead1), (& $at 2.7 $trail1), (& $at 2.0 $trail0)) $stripeHex $null -TwoSided -Depth ($wingDepth + 0.001)
  # engine: cylinder with a dark intake in front and a glowing exhaust behind
  Loft (Ring ($sx * 1.05) ($sy * 0.78) -5.2 0.50 0.50 12) (Ring ($sx * 1.05) ($sy * 0.78) -0.3 0.50 0.50 12) $hullHex $exhaustHex $darkHex
  # laser cannon with its flash suppressor tip
  $tx = $dx * 5.6; $ty = $dy * 5.6
  Loft (Ring $tx $ty -3.4 0.13 0.13 8) (Ring $tx $ty -0.4 0.13 0.13 8) $hullHex $hullHex $hullHex
  Loft (Ring $tx $ty -0.4 0.21 0.21 8) (Ring $tx $ty 0.2 0.21 0.21 8) $hullHex $darkHex $darkHex
} }

# faint engine glow behind the ship
foreach ($sx in 1, -1) { foreach ($sy in 1, -1) { $q = Proj (Xf ([double[]]@(($sx * 1.05), ($sy * 0.78), -5.4))); Glow $q.X $q.Y 46 0xF38BA8 55 } }

# astromech dome behind the cockpit (sorted with the rest of the ship)
$dome = Xf ([double[]]@(0, 0.62, -2.0)); $dp = Proj $dome; $dr = 0.36 * $K * ($D / ($D - $dome[2]))
[void]$items.Add([pscustomobject]@{ Depth = $dome[2] + 0.4; Pts = $null; Color = (C 235 0x6F8FCF) })

# draw back to front, with a faint edge line for definition
$edge = New-Object System.Drawing.Pen (C 45 0xCDD6F4), 1
foreach ($it in ($items | Sort-Object Depth)) {
  $brush = New-Object System.Drawing.SolidBrush $it.Color
  if ($it.Pts) { $g.FillPolygon($brush, $it.Pts); $g.DrawPolygon($edge, $it.Pts) }
  else { $g.FillPie($brush, [single]($dp.X - $dr), [single]($dp.Y - $dr), [single](2 * $dr), [single](2 * $dr), 180, 180) }
  $brush.Dispose()
}

# lit exhausts: dark nozzle ring, warm glow, bright core and a soft red halo
$rear = Xf ([double[]]@(0, 0, -1)); $rear0 = Xf ([double[]]@(0, 0, 0))
if (($rear[2] - $rear0[2]) -gt 0) {
  foreach ($sx in 1, -1) { foreach ($sy in 1, -1) {
    $e = Xf ([double[]]@(($sx * 1.05), ($sy * 0.78), -5.2)); $q = Proj $e; $er = 0.5 * $K * ($D / ($D - $e[2]))
    Glow $q.X $q.Y ($er * 2.3) 0xF38BA8 60
    Glow $q.X $q.Y ($er * 0.95) 0xFAB387 185
    $core = $er * 0.37
    $g.FillEllipse((New-Object System.Drawing.SolidBrush (C 190 0xF5E0DC)), [single]($q.X - $core), [single]($q.Y - $core), [single](2 * $core), [single](2 * $core))
  } }
}

$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"saved $Out"
