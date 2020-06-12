args <- commandArgs(trailingOnly = TRUE)
print(str(args))
dir.project <- args[1]
dir.input <- args[2]
dcm.zip <- args[3]
dir.inc.root <- "/Shared/inc_scratch/code"
dont.use <- c("loc", "cal", "orig")
dry.run <- FALSE
subject.id <- NULL
session.id <- NULL
if (length(args) > 3 ) {
  for (i in seq(4, length(args), 2)) {
    if (args[i] == "dir.inc.root") {
      dir.inc.root <- args[i+1]
    } else if (args[i] == "dont.use") {
      dont.use <- args[i+1]
      dont.use <- unlist(strsplit(dont.use, "[,]"))
    } else if (args[i] == "dry.run") {
      dry.run <- as.logical(args[i+1])
    } else if (args[i] == "subject") {
      subject.id <- args[i+1]
    } else if (args[i] == "session") {
      session.id <- args[i+1]
    }
  }
}

library(jsonlite)
library(tools)
source(paste0(dir.inc.root, "/dicom/ses_encode.R"))

# Locate files to convert -------------------------------------------------------
fls <- basename(file_path_sans_ext(list.files(dir.input, pattern="json")))
df <- data.frame(source = fls,
                 target = character(length(fls)),
                 destination = character(length(fls)),
                 mod = character(length(fls)),
                 use = numeric(length(fls))*0,
                 scan.num = numeric(length(fls)), 
                 stringsAsFactors = FALSE)
n.files <- nrow(df)

# Retreive identifiers ---------------------------------------------------------
if (is.null(subject.id)) {}
  participant <- data.frame(subject=character(1),
                   session=character(1),
                   stringsAsFactors = FALSE)
  subject <- unique(unlist(strsplit(df$source, split="__"))[2])
  if (grepl("_", subject)) { subject <- unlist(strsplit(subject, "_"))[1] }
  subject <- gsub("[^[:alnum:] ]", "", subject)
  if (length(subject) != 1) {
    warning(sprintf("dicom_sort WARNING: More than one unique subject identifier was found. Using %s", subject[1]))
  }
  participant$subject <- gsub(" ", "", subject[1])
} else {
  participant$subject <- subject.id
}

if (is.null(session.id)) {}
  session <- unique(unlist(strsplit(df$source, split="__"))[3])
  if (length(session) != 1) {
    warning(sprintf("dicom_sort WARNING: More than one unique session identifier was found. Using %s", session[1]))
  }
  participant$session <- gsub(" ", "", session[1])
  participant$session <- ses_encode(as.numeric(participant$session))
else {
  participant$session <- session.id
}

# Set participant values -------------------------------------------------------
prefix <- paste0("sub-", participant$subject,
                 "_ses-", participant$session)
px.file <- paste0(dir.project, "/participants.tsv")
if (file.exists(px.file)) {
  tf <- read.csv(px.file, sep = "\t", stringsAsFactors = FALSE)
  tf <- rbind(tf, participant)
  tf <- unique(tf)
  write.table(tf, px.file, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
} else {
  write.table(participant, px.file, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)
}


# Generate new filenames
desc.lut <- read.csv(paste0(dir.inc.root, "/lut/series_description.lut"), sep="\t", stringsAsFactors = FALSE)
for (i in 1:n.files) {
  desc <- unlist(strsplit(df$source[i], split="__"))
  df$scan.num[i] <- as.numeric(unlist(strsplit(df$source[i], split="__"))[4])
  if (desc[5] == "CBF") { desc <- desc[1:5] }
  desc <- paste(desc[5:length(desc)], collapse="")
  desc <- gsub("[^[:alnum:] ]", "", desc)
  
  found.desc <- FALSE
  which.desc <- NULL
  for (j in c("","a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z")) {
    if (desc %in% paste0(desc.lut$desc, j)) {
      found.desc <- TRUE
      which.desc <- which(paste0(desc.lut$desc, j) == desc)
    }
  }
  
  if (found.desc) {
    df$destination[i] <- desc.lut$dest[which.desc]
    flags <- t(desc.lut[which.desc, -c(1:2)])
    values <- unname(flags[ ,1])
    flags <- names(flags[ ,1])
    suffix <- character()
    
    if (df$destination[i] == "dwi") {
      bvec <- as.data.frame(table(as.numeric(read.csv(paste0(dir.input, "/", df$source[i], ".bval"), sep=" ", header=FALSE))))
      if (nrow(bvec)>2){
        values[flags=="acq"] <- c(paste0("multishell"))
      } else {
        values[flags=="acq"] <- c(paste0("b", paste(bvec[ ,1], collapse="+"), "v", paste(bvec[ ,2], collapse="+")))
      }
    }
    if (df$destination[i] %in% c("dwi", "func", "fmap")) {
      series.num <- unlist(strsplit(df$source[i], "__"))[4]
      dcm.temp <- read_json(paste0(dir.input, "/", df$source[i], ".json"), simplifyVector = T)
      phase.orient <- dcm.temp$InPlanePhaseEncodingDirectionDICOM
      phase.dir <- dcm.temp$ImageOrientationPatientDICOM
      phase.dir <- as.integer(phase.dir*phase.dir + 0.5)
      if (phase.dir[1]==1 && phase.dir[6]==1) {
        if (phase.orient == "COL") {
          values[flags=="dir"] <- "AP"
        } else if (phase.orient == "ROW") {
          values[flags=="dir"] <- "RL"
        }
      } else if (phase.dir[1]==1 && phase.dir[5]==1) {
        if (phase.orient == "COL") {
          values[flags=="dir"] <- "SI"
        } else if (phase.orient == "ROW") {
          values[flags=="dir"] <- "AP"
        }
      } else if (phase.dir[2]==1 && phase.dir[6]==1) {
        if (phase.orient == "COL") {
          values[flags=="dir"] <- "SI"
        } else if (phase.orient == "ROW") {
          values[flags=="dir"] <- "RL"
        }
      }
    }
    
    if (df$destination[i] == "func" & values[flags=="task"]=="-") {
      ## how to get correct task
    }
    
    for (j in 1:length(flags)) {
      if (values[j] != "-") {
        if (flags[j]=="mod") {
          suffix <- c(suffix, values[j])
          df$mod[i] <- values[j]
        } else {
          suffix <- c(suffix, flags[j], "-", values[j], "_")
        }
      }
    }
    if (!(df$destination[i] %in% dont.use)) { # maybe rethink what this is checking so that other things can be excluded too
      df$use[i] <- 1
    }
    df$target[i] <- paste(prefix, "_", paste(suffix, collapse=""), sep="")
  } else {
    stop(sprintf("inc_dcmSort ERROR: %s not in series_description.lut", df$source[i]))
  }
}

## FIX DWI and FUNC flags here, to get the correct acq and dir flags

## Deal with multiple runs here
name.ls <- unique(df$target)
name.ls <- name.ls[name.ls != ""]
for (i in 1:length(name.ls)) {
  which.name <- df$target[df$target == name.ls[i]]
  if (length(which.name) > 1) {
    for (j in 1:length(which.name)) {
      tmp <- unlist(strsplit(unlist(strsplit(which.name[j], "_")), "-"))
      if ("acq" %in% tmp) {
        idx <- which(tmp == "acq")+1
        tmp[idx] <- paste0(tmp[idx], "+", j-1)
      } else if ("site" %in% tmp) {
        idx <- which(tmp == "site")+1
        tmp <- c(tmp[1:idx], "acq", j-1, tmp[(idx+1):length(tmp)])
      } else if ("ses" %in% tmp) {
        idx <- which(tmp == "ses")+1
        tmp <- c(tmp[1:idx], "acq", j-1, tmp[(idx+1):length(tmp)])
      } else {
        idx <- which(tmp == "sub")+1
        tmp <- c(tmp[1:idx], "acq", j-1, tmp[(idx+1):length(tmp)])
      }
      new.target <- character()
      for (k in 1:length(tmp)) {
        if (k %% 2 == 1) {
          new.target <- paste0(new.target, tmp[k], "-")
        } else {
          new.target <- paste0(new.target, tmp[k], "_")
        }
      }
      which.name[j] <- substr(new.target, 1, nchar(new.target)-1)
    }
    df$target[df$target == name.ls[i]] <- which.name
  }
}


if (dry.run) {
  return(df)
} else {
  # Write session.tsv
  session.tsv <- df[ , c("target", "destination", "mod", "use")]
  colnames(session.tsv)[1:2] <- c("filename", "type")
  dir.session <- paste0(dir.project, "/rawdata/sub-", participant$subject, "/ses-", participant$session)
  dir.create(dir.session, recursive = TRUE, showWarnings=FALSE)
  write.table(session.tsv, file=paste0(dir.session, "/session.tsv"), sep="\t",
              quote=FALSE, row.names=FALSE, col.names=TRUE)
  
  # Copy nifti files to new locations, rename temp files for QC ------------------
  for (i in 1:n.files) {
    if (df$use[i] == 1) {
      dir.save=paste0(dir.session, "/", df$destination[i])
      dir.create(dir.save, recursive = TRUE, showWarnings=FALSE)
      if (df$destination[i] == "dwi") {
        file.copy(from=paste0(dir.input, "/", df$source[i], ".bval"), to=paste0(dir.save, "/", df$target[i], ".bval"))
        file.copy(from=paste0(dir.input, "/", df$source[i], ".bvec"), to=paste0(dir.save, "/", df$target[i], ".bvec"))
        file.copy(from=paste0(dir.input, "/", df$source[i], ".json"), to=paste0(dir.save, "/", df$target[i], ".json"))
        file.copy(from=paste0(dir.input, "/", df$source[i], ".nii.gz"), to=paste0(dir.save, "/", df$target[i], ".nii.gz"))
        file.rename(from=paste0(dir.input, "/", df$source[i], ".bval"), to=paste0(dir.input, "/", df$target[i], ".bval"))
        file.rename(from=paste0(dir.input, "/", df$source[i], ".bvec"), to=paste0(dir.input, "/", df$target[i], ".bvec"))
        file.rename(from=paste0(dir.input, "/", df$source[i], ".json"), to=paste0(dir.input, "/", df$target[i], ".json"))
        file.rename(from=paste0(dir.input, "/", df$source[i], ".nii.gz"), to=paste0(dir.input, "/", df$target[i], ".nii.gz"))
      } else {
        file.copy(from=paste0(dir.input, "/", df$source[i], ".json"), to=paste0(dir.save, "/", df$target[i], ".json"))
        file.copy(from=paste0(dir.input, "/", df$source[i], ".nii.gz"), to=paste0(dir.save, "/", df$target[i], ".nii.gz"))
        file.rename(from=paste0(dir.input, "/", df$source[i], ".json"), to=paste0(dir.input, "/", df$target[i], ".json"))
        file.rename(from=paste0(dir.input, "/", df$source[i], ".nii.gz"), to=paste0(dir.input, "/", df$target[i], ".nii.gz"))
      }
    }
  }
  
  # Copy DICOM zip file ----------------------------------------------------------
  dir.create(paste0(dir.project, "/sourcedata"), recursive=TRUE, showWarnings=FALSE)
  file.copy(from=dcm.zip, to=paste0(dir.project, "/sourcedata/", prefix, "_DICOM.zip"))
}
  
