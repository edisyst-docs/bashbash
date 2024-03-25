  
Get-Alias -Definition Get-ChildItem
$var1 = 5
$var2 = 10
$var3 = $var1 + $var2
echo $var3

Write-Host "Premi un tasto per continuare ..."
$x = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")