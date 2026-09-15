param(
    [string]$SourceRoot = "",
    [string]$WebRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($WebRoot)) { $WebRoot = $PSScriptRoot }
if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Split-Path $WebRoot -Parent }

$UcOutDir = Join-Path $WebRoot "uc"
$ModOutDir = Join-Path $WebRoot "modulos"
New-Item -ItemType Directory -Force -Path $UcOutDir | Out-Null
New-Item -ItemType Directory -Force -Path $ModOutDir | Out-Null

function HtmlEncode([string]$s) {
    if ($null -eq $s) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($s)
}

function Inline-Markdown([string]$line) {
    $encoded = HtmlEncode $line
    $encoded = [regex]::Replace($encoded, '\*\*(.+?)\*\*', '<strong>$1</strong>')
    $encoded = [regex]::Replace($encoded, '`(.+?)`', '<code>$1</code>')
    return $encoded
}

function Find-Md([string]$pattern) {
    Get-ChildItem -Path $SourceRoot -Filter $pattern -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike "$WebRoot*" } |
        Select-Object -First 1
}

function Extract-Field([string[]]$lines, [string]$label) {
    foreach ($line in $lines) {
        $pattern = '^\s*[-]?\s*\*\*' + [regex]::Escape($label) + ':\*\*\s*(.+?)(?:\s{2,})?$'
        if ($line -match $pattern) { return $Matches[1].Trim() }
    }
    return ""
}

function Extract-SectionBullets([string[]]$lines, [string]$heading) {
    $items = New-Object System.Collections.Generic.List[string]
    $inSection = $false
    foreach ($line in $lines) {
        if ($line -match '^###\s+(.+)$') {
            $title = $Matches[1].Trim()
            if ($inSection -and $title -ne $heading) { break }
            $inSection = ($title -eq $heading)
            continue
        }
        if ($inSection -and $line -match '^-\s+(.+)$') {
            $items.Add($Matches[1].Trim())
        }
        if ($inSection -and $line -match '^##\s+') { break }
    }
    return $items
}

function Extract-WhereRows([string[]]$lines) {
    $rows = New-Object System.Collections.Generic.List[object]
    $inSection = $false
    foreach ($line in $lines) {
        if ($line -match '^##\s+Onde aparece neste plano') {
            $inSection = $true
            continue
        }
        if ($inSection -and $line -match '^##\s+') { break }
        if ($inSection -and $line -match '^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$') {
            $c = $Matches[1].Trim()
            $a = $Matches[2].Trim()
            $d = $Matches[3].Trim()
            if ($c -notin @("Curso","---") -and $c -notmatch '^-+$') {
                $rows.Add([pscustomobject]@{Course=$c;Year=$a;Discipline=$d})
            }
        }
    }
    return $rows
}

$style = @'
:root{--ink:#0f172a;--muted:#64748b;--line:#e2e8f0;--brand:#164e63;--accent:#0369a1;--soft:#f8fafc}
*{box-sizing:border-box}
body{margin:0;font-family:Arial,Helvetica,sans-serif;background:var(--soft);color:var(--ink);line-height:1.55}
header{background:linear-gradient(135deg,#0f172a,#164e63);color:white;padding:38px 22px}
.wrap,main{max-width:1000px;margin:auto}
.eyebrow{font-size:.85rem;color:#bae6fd;font-weight:700;text-transform:uppercase;letter-spacing:.05em}
h1{font-size:2rem;line-height:1.2;margin:.35rem 0 .4rem}
.subtitle{color:#cbd5e1}
nav{background:white;border-bottom:1px solid var(--line);position:sticky;top:0;z-index:10}
nav .wrap{display:flex;gap:8px;align-items:center;flex-wrap:wrap;padding:9px 22px}
nav a{text-decoration:none;color:var(--ink);font-weight:700;padding:7px 9px;border-radius:8px}
nav a:hover{background:#e2e8f0}
main{padding:24px 22px 48px}
.breadcrumb{font-size:.92rem;color:var(--muted);margin-bottom:18px}
.breadcrumb a{color:var(--accent);text-decoration:none}
.card{background:white;border:1px solid var(--line);border-radius:16px;padding:20px;margin:0 0 18px;box-shadow:0 7px 22px rgba(15,23,42,.05)}
.meta{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px}
.meta div{background:#f8fafc;border:1px solid var(--line);border-radius:12px;padding:12px}
.meta strong{display:block;font-size:.78rem;text-transform:uppercase;color:var(--muted);margin-bottom:3px}
h2{margin:0 0 12px;font-size:1.25rem}
ul{padding-left:1.3rem} li{margin:.45rem 0}
table{width:100%;border-collapse:collapse}
th,td{padding:10px 12px;border-bottom:1px solid var(--line);text-align:left}
th{background:#f1f5f9}
.actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:20px}
.btn{display:inline-block;text-decoration:none;background:#0f172a;color:white;padding:10px 14px;border-radius:10px;font-weight:700}
.btn.secondary{background:#0369a1}
.source{font-size:.9rem;color:var(--muted)}
footer{padding:24px 22px;text-align:center;color:var(--muted)}
@media(max-width:650px){h1{font-size:1.55rem}nav{position:static}}
'@

# ---- UCs dos dois cursos de 1.º ano ----
$ucs = @(
# TSTER
@{Code="UC01172";Name="Executar desenho técnico em CAD"},
@{Code="UC03077";Name="Executar desenho técnico de esquemas elétricos"},
@{Code="UC00491";Name="Implementar as normas de segurança e saúde no trabalho em instalações de energia"},
@{Code="UC03079";Name="Efetuar medições e controlo metrológico"},
@{Code="UC03080";Name="Executar operações de serralharia de bancada elementares"},
@{Code="UC03082";Name="Executar operações de ligação de peças"},
@{Code="UC03087";Name="Executar a montagem, reparação e ligação de quadro elétrico à rede"},
@{Code="UC00668";Name="Executar a instalação de motores elétricos"},
@{Code="UC03099";Name="Instalar sistemas de domótica"},
@{Code="UC03104";Name="Instalar sistemas solares térmicos em termossifão"},
@{Code="UC03105";Name="Instalar sistemas solares térmicos de circulação forçada"},
@{Code="UC01799";Name="Instalar sistema fotovoltaico para autoconsumo"},
@{Code="UC01415";Name="Propor materiais e tratamentos"},
@{Code="UC03076";Name="Preparar e orçamentar a execução de uma instalação energética"},
@{Code="UC03086";Name="Dimensionar componentes de circuitos elétricos"},
@{Code="UC00034";Name="Colaborar e trabalhar em equipa"},
@{Code="UC03081";Name="Executar operações de maquinação no fabrico de peças"},
@{Code="UC03083";Name="Executar soldadura a arco elétrico"},
@{Code="UC03098";Name="Executar instalações elétricas residenciais"},
@{Code="UC03108";Name="Efetuar a manutenção e reparação de sistemas térmicos"},
@{Code="UC03113";Name="Instalar superfícies radiantes em sistemas de climatização"},
@{Code="UC03102";Name="Configurar uma instalação de energia térmica"},
@{Code="UC03103";Name="Executar a montagem e manutenção de circuitos hidráulicos e pneumáticos"},
@{Code="UC00493";Name="Executar trabalhos em altura em estruturas e plataformas"},
@{Code="UC03097";Name="Executar trabalhos verticais em cordas"},
@{Code="UC03106";Name="Instalar caldeira com recuperador de calor em sistemas solares térmicos"},
@{Code="UC03107";Name="Instalar bomba de calor aerotérmica"},
@{Code="UC03101";Name="Prestar informação para uma aquisição e utilização mais eficiente de sistema térmico"},
@{Code="UC03109";Name="Dimensionar sistemas solares térmicos híbridos"},
@{Code="UC03111";Name="Configurar um sistema geotérmico de baixa entalpia"},
# adicionais TSSEF
@{Code="UC03094";Name="Atuar em situações de segurança de pessoas e bens no setor da energia"},
@{Code="UC03088";Name="Instalar sistemas de conversão de corrente elétrica"},
@{Code="UC03089";Name="Instalar sistemas solares fotovoltaicos"},
@{Code="UC03090";Name="Efetuar a manutenção e reparação de sistemas fotovoltaicos"},
@{Code="UC03100";Name="Adotar práticas de gestão da qualidade no setor da energia"},
@{Code="UC03078";Name="Executar desenho técnico simples de construção civil"},
@{Code="UC01994";Name="Instalar e programar automatismos e autómatos"},
@{Code="UC03091";Name="Instalar sistemas eólicos onshore"},
@{Code="UC03092";Name="Instalar sistemas eólicos offshore"},
@{Code="UC03084";Name="Efetuar a manutenção de órgãos de máquinas e mecanismos"},
@{Code="UC03085";Name="Manobrar meios de elevação e transporte de grande porte"},
@{Code="UC00649";Name="Executar instalações elétricas industriais"},
@{Code="UC03093";Name="Efetuar a manutenção e reparação de sistemas eólicos"},
@{Code="UC03075";Name="Prestar informação ao cliente para uma utilização eficiente de sistemas eólicos e fotovoltaicos"},
@{Code="UC03096";Name="Dimensionar sistemas eólicos para autoconsumo"}
)

# eliminar duplicados por código
$ucs = $ucs | Group-Object Code | ForEach-Object { $_.Group[0] }

$missing = New-Object System.Collections.Generic.List[string]
$made = 0

foreach ($u in $ucs) {
    $md = Find-Md "$($u.Code).md"
    $area = "522 — Eletricidade e Energia"
    $level = "4"
    $name = $u.Name
    $realizacoes = @()
    $whereRows = @()

    if ($md) {
        $lines = Get-Content -LiteralPath $md.FullName -Encoding UTF8
        $a = Extract-Field $lines "Área"
        $n = Extract-Field $lines "Nível de qualificação associado"
        $d = Extract-Field $lines "Designação oficial"
        if ($a) { $area = $a }
        if ($n) { $level = $n }
        if ($d) { $name = $d }
        $realizacoes = Extract-SectionBullets $lines "Realizações"
        $whereRows = Extract-WhereRows $lines
    } else {
        $missing.Add($u.Code)
    }

    $whereHtml = ""
    if ($whereRows.Count -gt 0) {
        $rows = $whereRows | ForEach-Object {
            "<tr><td>$(HtmlEncode $_.Course)</td><td>$(HtmlEncode $_.Year)</td><td>$(HtmlEncode $_.Discipline)</td></tr>"
        }
        $whereHtml = "<table><thead><tr><th>Curso</th><th>Ano</th><th>Disciplina</th></tr></thead><tbody>$($rows -join "`n")</tbody></table>"
    } else {
        $whereHtml = "<p>Consultar o plano do curso para o enquadramento desta UC.</p>"
    }

    $realHtml = if ($realizacoes.Count -gt 0) {
        ($realizacoes | ForEach-Object { "<li>$(Inline-Markdown $_)</li>" }) -join "`n"
    } else {
        "<li>Descrição detalhada não encontrada automaticamente no MD.</li>"
    }

    $courseButtons = New-Object System.Collections.Generic.List[string]
    $courses = @($whereRows | ForEach-Object { $_.Course } | Select-Object -Unique)
    if ($courses -match 'TISTER') { $courseButtons.Add('<a class="btn secondary" href="../1_TSTER.html">← 1_TSTER</a>') }
    if ($courses -match 'TSEF')   { $courseButtons.Add('<a class="btn secondary" href="../1_TSSEF.html">← 1_TSSEF</a>') }
    if ($courseButtons.Count -eq 0) {
        $courseButtons.Add('<a class="btn secondary" href="../1_TSTER.html">1_TSTER</a>')
        $courseButtons.Add('<a class="btn secondary" href="../1_TSSEF.html">1_TSSEF</a>')
    }

    $html = @"
<!doctype html>
<html lang="pt-PT">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$($u.Code) — $(HtmlEncode $name)</title>
<style>$style</style>
</head>
<body>
<header><div class="wrap"><div class="eyebrow">Unidade de Competência</div><h1>$($u.Code)</h1><div class="subtitle">$(HtmlEncode $name)</div></div></header>
<nav><div class="wrap"><a href="../index.html">Início</a><a href="../1_TSTER.html">1_TSTER</a><a href="../1_TSSEF.html">1_TSSEF</a><a href="../2_TISSF.html">2_TISSF</a></div></nav>
<main>
<div class="breadcrumb"><a href="../index.html">Início</a> › <strong>$($u.Code)</strong></div>
<section class="card"><div class="meta">
<div><strong>Código</strong>$($u.Code)</div>
<div><strong>Nível</strong>$(HtmlEncode $level)</div>
<div><strong>Área</strong>$(HtmlEncode $area)</div>
</div></section>
<section class="card"><h2>Designação oficial</h2><p>$(HtmlEncode $name)</p></section>
<section class="card"><h2>Onde aparece neste plano</h2>$whereHtml</section>
<section class="card"><h2>Realizações</h2><ul>$realHtml</ul><p class="source">Fonte indicada no MD: Catálogo Nacional de Qualificações (CNQ) / ANQEP.</p></section>
<div class="actions">$($courseButtons -join "`n")</div>
</main>
<footer>Portal de apoio às aulas · AE Miranda do Corvo · 2026/2027</footer>
</body></html>
"@
    Set-Content -LiteralPath (Join-Path $UcOutDir "$($u.Code).html") -Value $html -Encoding UTF8
    $made++
}

# Atualizar os links de 1_TSTER e 1_TSSEF
foreach ($courseName in @("1_TSTER.html","1_TSSEF.html")) {
    $courseFile = Join-Path $WebRoot $courseName
    if (!(Test-Path $courseFile)) { continue }
    $courseHtml = Get-Content -LiteralPath $courseFile -Raw -Encoding UTF8

    if ($courseHtml -notmatch '\.uc-link\{') {
        $courseHtml = $courseHtml -replace '</style>', @'
.uc-link{color:#0369a1;text-decoration:none;border-bottom:1px dotted #0369a1}
.uc-link:hover{color:#0c4a6e;border-bottom-style:solid}
</style>
'@
    }

    foreach ($u in $ucs) {
        $code = $u.Code
        $patternPlain = '<strong>' + [regex]::Escape($code) + '</strong>'
        $replacement = '<a class="uc-link" href="uc/' + $code + '.html"><strong>' + $code + '</strong></a>'
        $courseHtml = [regex]::Replace($courseHtml, $patternPlain, $replacement)
    }
    Set-Content -LiteralPath $courseFile -Value $courseHtml -Encoding UTF8
}

# ---- Módulos do 2_TISSF ----
$modules = @(
    @{Code="4559";Name="Pneumática e hidráulica";Hours="30 h";Start="10-09-2026"},
    @{Code="4555";Name="Tecnologia dos materiais";Hours="60 h";Start="25-09-2026"}
)

foreach ($m in $modules) {
    $md = Find-Md "$($m.Code) - *.md"
    $course = "Técnico Instalador de Sistemas Solares Fotovoltaicos"
    $discipline = "Tecnologia e Processos"
    $year = "2026/2027"
    $hours = $m.Hours

    if ($md) {
        $lines = Get-Content -LiteralPath $md.FullName -Encoding UTF8
        $v = Extract-Field $lines "Curso"; if ($v) { $course = $v }
        $v = Extract-Field $lines "Disciplina"; if ($v) { $discipline = $v }
        $v = Extract-Field $lines "Ano letivo"; if ($v) { $year = $v }
        $v = Extract-Field $lines "Carga horária"; if ($v) { $hours = $v }
    }

    $html = @"
<!doctype html>
<html lang="pt-PT">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$($m.Code) — $(HtmlEncode $m.Name)</title>
<style>$style</style>
</head>
<body>
<header><div class="wrap"><div class="eyebrow">2_TISSF · Tecnologia e Processos</div><h1>$($m.Code)</h1><div class="subtitle">$(HtmlEncode $m.Name)</div></div></header>
<nav><div class="wrap"><a href="../index.html">Início</a><a href="../1_TSTER.html">1_TSTER</a><a href="../1_TSSEF.html">1_TSSEF</a><a href="../2_TISSF.html">2_TISSF</a></div></nav>
<main>
<div class="breadcrumb"><a href="../index.html">Início</a> › <a href="../2_TISSF.html">2_TISSF</a> › Tecnologia e Processos › <strong>$($m.Code)</strong></div>
<section class="card"><div class="meta">
<div><strong>Código / módulo</strong>$($m.Code)</div>
<div><strong>Disciplina</strong>$(HtmlEncode $discipline)</div>
<div><strong>Carga horária</strong>$(HtmlEncode $hours)</div>
<div><strong>Ano letivo</strong>$(HtmlEncode $year)</div>
</div></section>
<section class="card"><h2>Unidade / módulo</h2><p>$(HtmlEncode $m.Name)</p><p><strong>Curso:</strong> $(HtmlEncode $course)</p></section>
<section class="card"><h2>Planificação</h2><p>Esta página fica preparada para receber conteúdos, sumários, materiais e ligações à medida que o módulo for sendo desenvolvido.</p></section>
<div class="actions"><a class="btn secondary" href="../2_TISSF.html">← Voltar ao 2_TISSF</a></div>
</main>
<footer>Portal de apoio às aulas · AE Miranda do Corvo · 2026/2027</footer>
</body></html>
"@
    Set-Content -LiteralPath (Join-Path $ModOutDir "$($m.Code).html") -Value $html -Encoding UTF8
}

# Atualizar 2_TISSF
$tissfFile = Join-Path $WebRoot "2_TISSF.html"
if (Test-Path $tissfFile) {
    $h = Get-Content -LiteralPath $tissfFile -Raw -Encoding UTF8
    if ($h -notmatch '\.uc-link\{') {
        $h = $h -replace '</style>', @'
.uc-link{color:#0369a1;text-decoration:none;border-bottom:1px dotted #0369a1}
.uc-link:hover{color:#0c4a6e;border-bottom-style:solid}
</style>
'@
    }
    foreach ($m in $modules) {
        $code = $m.Code
        $h = [regex]::Replace($h, '<strong>'+$code+'</strong>', '<a class="uc-link" href="modulos/'+$code+'.html"><strong>'+$code+'</strong></a>')
        $h = [regex]::Replace($h, '<h3>'+$code+'(\s+—\s+[^<]+)</h3>', '<h3><a class="uc-link" href="modulos/'+$code+'.html">'+$code+'$1</a></h3>')
    }
    Set-Content -LiteralPath $tissfFile -Value $h -Encoding UTF8
}

Write-Host ""
Write-Host "=== RESTANTES CURSOS CONCLUÍDOS ===" -ForegroundColor Green
Write-Host "Páginas UC geradas/normalizadas: $made"
Write-Host "1_TSSEF atualizado com links para as UCs."
Write-Host "1_TSTER normalizado para partilhar as mesmas páginas UC."
Write-Host "2_TISSF atualizado e criadas páginas dos módulos 4559 e 4555."
if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "MDs de UC não encontrados:" -ForegroundColor Yellow
    $missing | Sort-Object -Unique | ForEach-Object { Write-Host " - $_" }
}
Write-Host ""
Write-Host "Testa localmente os três cursos. Se estiver tudo bem:"
Write-Host '  git add .'
Write-Host '  git commit -m "Completa páginas das UCs e módulos dos cursos"'
Write-Host '  git push'
