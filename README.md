![Polly](https://github.com/TetrationAnalytics/polymath/raw/images/polly.jpg "Polly")

# Polymath

Reconstitute Linux and macOS machine configurations via scripts

## Linux - Run scripts via

```
# polly <cookbook_name>
bash <(curl -fsSL https://raw.githubusercontent.com/TetrationAnalytics/polymath/master/polly)
```

Can also remove or install Chef without running a script:

```
# Remove Chef
bash <(curl -fsSL https://raw.githubusercontent.com/TetrationAnalytics/polymath/master/polly) nukechef

# Install Chef
bash <(curl -fsSL https://raw.githubusercontent.com/TetrationAnalytics/polymath/master/polly) chef
```

## Windows - Run scripts via

```
invoke-restmethod https://raw.githubusercontent.com/TetrationAnalytics/polymath/master/polly.ps1 | iex
```
