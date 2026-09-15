param(
    [string]$SourceRoot = "",
    [string]$WebRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($WebRoot)) {
    $WebRoot = $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Split-Path $WebRoot -Parent
}

$CourseFile = Join-Path $WebRoot "1_TSTER.html"
$UcOutDir = Join-Path $WebRoot "uc"

if (!(Test-Path $CourseFile)) {
    throw "Não encontrei 1_TSTER.html em: $WebRoot"
}

New-Item -ItemType Directory -Force -Path $UcOutDir | Out-Null

# UCs do 1_TSTER, pela ordem do plano.
$ucs = @(
    @{Code="UC01172"; Year="10.º"; Discipline="Desenho Técnico"; Name="Executar desenho técnico em CAD"},
    @{Code="UC03077"; Year="10.º"; Discipline="Desenho Técnico"; Name="Executar desenho técnico de esquemas elétricos"},
    @{Code="UC00491"; Year="10.º"; Discipline="Organização Industrial"; Name="Implementar as normas de segurança e saúde no trabalho em instalações de energia"},
    @{Code="UC03079"; Year="10.º"; Discipline="Práticas Oficinais"; Name="Efetuar medições e controlo metrológico"},
    @{Code="UC03080"; Year="10.º"; Discipline="Práticas Oficinais"; Name="Executar operações de serralharia de bancada elementares"},
    @{Code="UC03082"; Year="10.º"; Discipline="Práticas Oficinais"; Name="Executar operações de ligação de peças"},
    @{Code="UC03087"; Year="10.º"; Discipline="Práticas Oficinais"; Name="Executar a montagem, reparação e ligação de quadro elétrico à rede"},
    @{Code="UC00668"; Year="10.º"; Discipline="Práticas Oficinais"; Name="Executar a instalação de motores elétricos"},
    @{Code="UC03099"; Year="10.º"; Discipline="Práticas Oficinais"; Name="Instalar sistemas de domótica"},
    @{Code="UC03104"; Year="10.º"; Discipline="MMSR"; Name="Instalar sistemas solares térmicos em termossifão"},
    @{Code="UC03105"; Year="10.º"; Discipline="MMSR"; Name="Instalar sistemas solares térmicos de circulação forçada"},
    @{Code="UC01799"; Year="10.º"; Discipline="MMSR"; Name="Instalar sistema fotovoltaico para autoconsumo"},
    @{Code="UC01415"; Year="10.º"; Discipline="Tecnologia e Processos"; Name="Propor materiais e tratamentos"},
    @{Code="UC03076"; Year="10.º"; Discipline="Tecnologia e Processos"; Name="Preparar e orçamentar a execução de uma instalação energética"},
    @{Code="UC03086"; Year="10.º"; Discipline="Tecnologia e Processos"; Name="Dimensionar componentes de circuitos elétricos"},
    @{Code="UC00034"; Year="11.º"; Discipline="Organização Industrial"; Name="Colaborar e trabalhar em equipa"},
    @{Code="UC03081"; Year="11.º"; Discipline="Práticas Oficinais"; Name="Executar operações de maquinação no fabrico de peças"},
    @{Code="UC03083"; Year="11.º"; Discipline="Práticas Oficinais"; Name="Executar soldadura a arco elétrico"},
    @{Code="UC03098"; Year="11.º"; Discipline="Práticas Oficinais"; Name="Executar instalações elétricas residenciais"},
    @{Code="UC03108"; Year="11.º"; Discipline="MMSR"; Name="Efetuar a manutenção e reparação de sistemas térmicos"},
    @{Code="UC03113"; Year="11.º"; Discipline="MMSR"; Name="Instalar superfícies radiantes em sistemas de climatização"},
    @{Code="UC03102"; Year="11.º"; Discipline="Tecnologia e Processos"; Name="Configurar uma instalação de energia térmica"},
    @{Code="UC03103"; Year="12.º"; Discipline="Práticas Oficinais"; Name="Executar a montagem e manutenção de circuitos hidráulicos e pneumáticos"},
    @{Code="UC00493"; Year="12.º"; Discipline="Práticas Oficinais"; Name="Executar trabalhos em altura em estruturas e plataformas"},
    @{Code="UC03097"; Year="12.º"; Discipline="Práticas Oficinais"; Name="Executar trabalhos verticais em cordas"},
    @{Code="UC03106"; Year="12.º"; Discipline="MMSR"; Name="Instalar caldeira com recuperador de calor em sistemas solares térmicos"},
    @{Code="UC03107"; Year="12.º"; Discipline="MMSR"; Name="Instalar bomba de calor aerotérmica"},
    @{Code="UC03101"; Year="12.º"; Discipline="Tecnologia e Processos"; Name="Prestar informação para uma aquisição e utilização mais eficiente de sistema térmico"},
    @{Code="UC03109"; Year="12.º"; Discipline="Tecnologia e Processos"; Name="Dimensionar sistemas solares térmicos híbridos"},
    @{Code="UC03111"; Year="12.º"; Discipline="Tecnologia e Processos"; Name="Configurar um sistema geotérmico de baixa entalpia"}
)

function HtmlEncode([string]$s) {
    if ($null -eq $s) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($s)
}

function Inline-Markdown([string]$line) {
    $encoded = HtmlEncode $line
    $encoded = [regex]::Replace($encoded, '\*\*(.+?)\*\*', '<strong>$1</strong>')
    $encoded = [regex]::Replace($encoded, '`(.+?)`', '<code>$1</code>')
    $encoded = [regex]::Replace($encoded, '\[(.+?)\]\((.+?)\)', '<a href="$2">$1</a>')
    return $encoded
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

function Extract-Field([string[]]$lines, [string]$label) {
    foreach ($line in $lines) {
        $pattern = '^\-\s+\*\*' + [regex]::Escape($label) + ':\*\*\s*(.+)$'
        if ($line -match $pattern) { return $Matches[1].Trim() }
    }
    return ""
}

function Find-Md([string]$code) {
    $name = "$code.md"
    $found = Get-ChildItem -Path $SourceRoot -Filter $name -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike "$WebRoot*" } |
        Select-Object -First 1
    return $found
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
ul{padding-left:1.3rem}
li{margin:.45rem 0}
.actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:20px}
.btn{display:inline-block;text-decoration:none;background:#0f172a;color:white;padding:10px 14px;border-radius:10px;font-weight:700}
.btn.secondary{background:#0369a1}
.source{font-size:.9rem;color:var(--muted)}
footer{padding:24px 22px;text-align:center;color:var(--muted)}
@media(max-width:650px){h1{font-size:1.55rem}nav{position:static}}
'@

$created = 0
$missing = New-Object System.Collections.Generic.List[string]

for ($i = 0; $i -lt $ucs.Count; $i++) {
    $u = $ucs[$i]
    $md = Find-Md $u.Code
    $area = "522 — Eletricidade e Energia"
    $level = "4"
    $realizacoes = @()

    if ($md) {
        $lines = Get-Content -LiteralPath $md.FullName -Encoding UTF8
        $a = Extract-Field $lines "Área"
        $n = Extract-Field $lines "Nível de qualificação associado"
        if ($a) { $area = $a }
        if ($n) { $level = $n }
        $realizacoes = Extract-SectionBullets $lines "Realizações"
    } else {
        $missing.Add($u.Code)
    }

    $realHtml = if ($realizacoes.Count -gt 0) {
        ($realizacoes | ForEach-Object { "<li>$(Inline-Markdown $_)</li>" }) -join "`n"
    } else {
        "<li>Descrição detalhada não encontrada automaticamente no ficheiro MD local.</li>"
    }

    $prev = if ($i -gt 0) { $ucs[$i-1].Code } else { $null }
    $next = if ($i -lt $ucs.Count-1) { $ucs[$i+1].Code } else { $null }

    $navButtons = @('<a class="btn secondary" href="../1_TSTER.html">← Voltar ao 1_TSTER</a>')
    if ($prev) { $navButtons += "<a class=`"btn`" href=`"$prev.html`">← $prev</a>" }
    if ($next) { $navButtons += "<a class=`"btn`" href=`"$next.html`">$next →</a>" }
    $navButtonsHtml = $navButtons -join "`n"

    $sourceText = if ($md) { "Conteúdo construído a partir de $($md.Name)." } else { "Ficheiro MD de origem não localizado." }

    $html = @"
<!doctype html>
<html lang="pt-PT">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>$($u.Code) — $(HtmlEncode $u.Name)</title>
<style>
$style
</style>
</head>
<body>
<header>
  <div class="wrap">
    <div class="eyebrow">1_TSTER · $($u.Year) ano · $(HtmlEncode $u.Discipline)</div>
    <h1>$($u.Code)</h1>
    <div class="subtitle">$(HtmlEncode $u.Name)</div>
  </div>
</header>
<nav>
  <div class="wrap">
    <a href="../index.html">Início</a>
    <a href="../1_TSTER.html">1_TSTER</a>
    <a href="../1_TSSEF.html">1_TSSEF</a>
    <a href="../2_TISSF.html">2_TISSF</a>
  </div>
</nav>
<main>
  <div class="breadcrumb"><a href="../index.html">Início</a> › <a href="../1_TSTER.html">1_TSTER</a> › $(HtmlEncode $u.Discipline) › <strong>$($u.Code)</strong></div>

  <section class="card">
    <div class="meta">
      <div><strong>Código</strong>$($u.Code)</div>
      <div><strong>Ano</strong>$($u.Year) ano</div>
      <div><strong>Disciplina</strong>$(HtmlEncode $u.Discipline)</div>
      <div><strong>Nível</strong>$(HtmlEncode $level)</div>
      <div><strong>Área</strong>$(HtmlEncode $area)</div>
    </div>
  </section>

  <section class="card">
    <h2>Designação oficial</h2>
    <p>$(HtmlEncode $u.Name)</p>
  </section>

  <section class="card">
    <h2>Realizações</h2>
    <ul>
      $realHtml
    </ul>
    <p class="source">$(HtmlEncode $sourceText) Fonte indicada nos MD: Catálogo Nacional de Qualificações (CNQ) / ANQEP.</p>
  </section>

  <div class="actions">
    $navButtonsHtml
  </div>
</main>
<footer>Portal de apoio às aulas · AE Miranda do Corvo · 2026/2027</footer>
</body>
</html>
"@

    $dest = Join-Path $UcOutDir "$($u.Code).html"
    Set-Content -LiteralPath $dest -Value $html -Encoding UTF8
    $created++
}

# Atualizar links das UCs no curso.
$courseHtml = Get-Content -LiteralPath $CourseFile -Raw -Encoding UTF8

# Acrescentar estilo dos links apenas uma vez.
if ($courseHtml -notmatch '\.uc-link\{') {
    $courseHtml = $courseHtml -replace '</style>', @'
.uc-link{color:#0369a1;text-decoration:none;border-bottom:1px dotted #0369a1}
.uc-link:hover{color:#0c4a6e;border-bottom-style:solid}
</style>
'@
}

foreach ($u in $ucs) {
    $code = $u.Code
    # Só substitui <strong>UCxxxxx</strong> ainda não ligado.
    $pattern = '<strong>' + [regex]::Escape($code) + '</strong>'
    $replacement = '<a class="uc-link" href="uc/' + $code + '.html"><strong>' + $code + '</strong></a>'
    $courseHtml = [regex]::Replace($courseHtml, $pattern, $replacement)
}
Set-Content -LiteralPath $CourseFile -Value $courseHtml -Encoding UTF8

Write-Host ""
Write-Host "=== PILOTO 1_TSTER CONCLUÍDO ===" -ForegroundColor Green
Write-Host "Páginas UC criadas: $created"
Write-Host "Pasta: $UcOutDir"
Write-Host "Curso atualizado: $CourseFile"
if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "MDs não encontrados automaticamente:" -ForegroundColor Yellow
    $missing | ForEach-Object { Write-Host " - $_" }
}
Write-Host ""
Write-Host "Agora testa localmente 1_TSTER.html. Se estiver bem:"
Write-Host '  git add .'
Write-Host '  git commit -m "Adiciona páginas das UCs do 1_TSTER"'
Write-Host '  git push'
