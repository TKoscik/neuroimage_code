ses_decode <- function(x) {
  conv.set <- c(0:9, "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l",
                "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z")
  # conv.set <- c(1:8, "a", "b", "c", "d", "e", "f", "h", "i", "j", "k",
  #               "m", "n", "o", "p", "q", "r", "s", "t", "v", "w", "x", "y", "z")
  n <- length(conv.set)
  x <- substring(x, seq(1, nchar(x), 1), seq(1, nchar(x), 1))
  date.vec <- 0
  for (i in 1:length(x)) {
    date.vec <- date.vec + ((which(conv.set == x[i])) * (n ^ (length(x)- i)))
  }
  ses <- format(date.vec, scientific=F)
  return(ses)
}
