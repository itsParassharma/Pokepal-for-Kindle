-- A saved stream keeps random choices stable across both Lua runtimes.
return function(s,n)
 s.seed=(s.seed*48271)%2147483647
 return math.floor(s.seed%n)+1
end
