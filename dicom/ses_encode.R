ses_encode <- function(x) {
  conv.set <- c(0:9, "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l",
                "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z")
  # conv.set <- c(1:8, "a", "b", "c", "d", "e", "f", "h", "i", "j", "k",
  #               "m", "n", "o", "p", "q", "r", "s", "t", "v", "w", "x", "y", "z")
  n <- length(conv.set)
  ses <- character()
  r <- -1
  q <- 0
  while (r != 0) {
    r <- x %/% n
    q <- x %% n
    x <- r
    ses <- c(ses, conv.set[q])
  }
  ses <- paste(rev(ses), collapse="")
  return(ses)
}
