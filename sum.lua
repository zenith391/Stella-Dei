function gaussian(x, mean, stddev)
  local a = (x - mean) / stddev
  return math.exp(-0.5 * a * a)
end

local sumWeight = 0
local stddev = 2
for i = 0, 15 do
  local w = gaussian(i+(16-1)/2, (16-1)/2.0, stddev)
  sumWeight = sumWeight + math.cos(i * math.pi / 16.0) * 0.5 + 0.5
end
print(sumWeight)

local weights = {}
local sum = 0
print("{")
for i=0, 15 do
  local w = gaussian(i+(16-1)/2, (16-1)/2.0, stddev) / sumWeight;
  sum = sum + w
  print("\t" .. w .. ",")
end
print("}")
print(sum)

