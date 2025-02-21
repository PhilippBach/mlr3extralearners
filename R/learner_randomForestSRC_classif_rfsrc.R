#' @title Classification Random Forest SRC Learner
#' @author RaphaelS1
#' @name mlr_learners_classif.rfsrc
#'
#' @template class_learner
#' @templateVar id classif.rfsrc
#' @templateVar caller rfsrc
#'
#' @section Custom mlr3 defaults:
#' - `cores`:
#'   - Actual default: Auto-detecting the number of cores
#'   - Adjusted default: 1
#'   - Reason for change: Threading conflicts with explicit parallelization via \CRANpkg{future}.
#'
#' @references
#' Breiman L (2001). “Random Forests.”
#' Machine Learning, 45(1), 5–32. ISSN 1573-0565, doi: 10.1023/A:1010933404324.
#'
#' @template seealso_learner
#' @template example
#' @export
LearnerClassifRandomForestSRC = R6Class("LearnerClassifRandomForestSRC",
  inherit = LearnerClassif,

  public = list(
    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    initialize = function() {
      ps = ps(
          ntree = p_int(default = 1000, lower = 1L, tags = c("train", "predict")),
          mtry = p_int(lower = 1L, tags = "train"),
          nodesize = p_int(default = 15L, lower = 1L, tags = "train"),
          nodedepth = p_int(lower = 1L, tags = "train"),
          splitrule = p_fct(
            levels = c("gini", "auc", "entropy"),
            default = "gini", tags = "train"),
          nsplit = p_int(lower = 0, default = 10, tags = "train"),
          importance = p_fct(
            default = "FALSE",
            levels = c("FALSE", "TRUE", "none", "permute", "random", "anti"),
            tags = c("train", "predict")),
          block.size = p_int(default = 10L, lower = 1L, tags = c("train", "predict")),
          ensemble = p_fct(
            default = "all", levels = c("all", "oob", "inbag"),
            tags = c("train", "predict")),
          bootstrap = p_fct(
            default = "by.root",
            levels = c("by.root", "by.node", "none", "by.user"), tags = "train"),
          samptype = p_fct(
            default = "swor", levels = c("swor", "swr"),
            tags = "train"),
          samp = p_uty(tags = "train"),
          membership = p_lgl(default = FALSE, tags = c("train", "predict")),
          sampsize = p_uty(tags = "train"),
          na.action = p_fct(
            default = "na.omit", levels = c("na.omit", "na.impute"),
            tags = c("train", "predict")),
          nimpute = p_int(default = 1L, lower = 1L, tags = "train"),
          ntime = p_int(lower = 1L, tags = "train"),
          cause = p_int(lower = 1L, tags = "train"),
          proximity = p_fct(
            default = "FALSE",
            levels = c("FALSE", "TRUE", "inbag", "oob", "all"),
            tags = c("train", "predict")),
          distance = p_fct(
            default = "FALSE",
            levels = c("FALSE", "TRUE", "inbag", "oob", "all"),
            tags = c("train", "predict")),
          forest.wt = p_fct(
            default = "FALSE",
            levels = c("FALSE", "TRUE", "inbag", "oob", "all"),
            tags = c("train", "predict")),
          xvar.wt = p_uty(tags = "train"),
          split.wt = p_uty(tags = "train"),
          forest = p_lgl(default = TRUE, tags = "train"),
          var.used = p_fct(
            default = "FALSE",
            levels = c("FALSE", "all.trees", "by.tree"), tags = c("train", "predict")),
          split.depth = p_fct(
            default = "FALSE",
            levels = c("FALSE", "all.trees", "by.tree"), tags = c("train", "predict")),
          seed = p_int(upper = -1L, tags = c("train", "predict")),
          do.trace = p_lgl(default = FALSE, tags = c("train", "predict")),
          statistics = p_lgl(default = FALSE, tags = c("train", "predict")),
          get.tree = p_uty(tags = "predict"),
          outcome = p_fct(
            default = "train", levels = c("train", "test"),
            tags = "predict"),
          ptn.count = p_int(default = 0L, lower = 0L, tags = "predict"),
          cores = p_int(default = 1L, lower = 1L, tags = c("train", "predict"))
      )

      super$initialize(
        id = "classif.rfsrc",
        packages = "randomForestSRC",
        feature_types = c("logical", "integer", "numeric", "factor"),
        predict_types = c("response", "prob"),
        param_set = ps,
        # selected features is possible but there's a bug somewhere in rfsrc so that the model
        # can be trained but not predicted. so public method retained but property not included
        properties = c(
          "weights", "missings", "importance", "oob_error",
          "twoclass", "multiclass"),
        man = "mlr3extralearners::mlr_learners_classif.rfsrc"
      )
    },


    #' @description
    #' The importance scores are extracted from the model slot `importance`, returned for
    #' 'all'.
    #' @return Named `numeric()`.
    importance = function() {
      if (is.null(self$model$importance) & !is.null(self$model)) {
        mlr3misc::stopf("Set 'importance' to one of: {'TRUE', 'permute', 'random', 'anti'}.")
      }

      sort(self$model$importance[, 1], decreasing = TRUE)
    },

    #' @description
    #' Selected features are extracted from the model slot `var.used`.
    #' @return `character()`.
    selected_features = function() {
      if (is.null(self$model$var.used) & !is.null(self$model)) {
        mlr3misc::stopf("Set 'var.used' to one of: {'all.trees', 'by.tree'}.")
      }

      names(self$model$var.used)
    },

    #' @description
    #' OOB error extracted from the model slot `err.rate`.
    #' @return `numeric()`.
    oob_error = function() {
      as.numeric(self$model$err.rate[self$model$ntree, 1])
    }
  ),

  private = list(
    .train = function(task) {
      pv = self$param_set$get_values(tags = "train")
      cores = pv$cores %??% 1L

      if ("weights" %in% task$properties) {
        pv$case.wt = as.numeric(task$weights$weight) # nolint
      }

      mlr3misc::invoke(randomForestSRC::rfsrc,
        formula = task$formula(), data = as.data.frame(task$data()),
        .args = pv, .opts = list(rf.cores = cores))
    },

    .predict = function(task) {
      newdata = as.data.frame(task$data(cols = task$feature_names))
      pars = self$param_set$get_values(tags = "predict")
      cores = pars$cores %??% 1L
      pred = mlr3misc::invoke(predict,
        object = self$model,
        newdata = newdata,
        .args = pars,
        .opts = list(rf.cores = cores))

      if (self$predict_type == "response") {
        list(response = pred$class)
      } else {
        list(prob = pred$predicted)
      }
    }
  )
)

.extralrns_dict$add("classif.rfsrc", LearnerClassifRandomForestSRC)
