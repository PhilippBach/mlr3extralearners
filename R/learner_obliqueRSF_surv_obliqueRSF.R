#' @title Survival Oblique Random Survival Forest Learner
#'
#' @name mlr_learners_surv.obliqueRSF
#' @author adibender
#'
#' @template class_learner
#' @templateVar id surv.obliqueRSF
#' @templateVar caller ORSF
#'
#' @section Custom mlr3 defaults:
#' - `verbose`:
#'   - Actual default: `TRUE`
#'   - Adjusted default: `FALSE`
#'   - Reason for change: mlr3 already has it's own verbose set to `TRUE` by default
#'
#' @references
#' Jaeger BC, Long DL, Long DM, Sims M, Szychowski JM, Min Y, Mcclure LA, Howard G, Simon N (2019).
#' “Oblique random survival forests.” The Annals of Applied Statistics, 13(3), 1847–1883.
#' ISSN 1932-6157, 1941-7330, doi: 10.1214/19-AOAS1261,
#' https://projecteuclid.org/euclid.aoas/1571277776.
#'
#' @template seealso_learner
#' @template example
#' @export
LearnerSurvObliqueRSF = R6Class("LearnerSurvObliqueRSF",
  inherit = mlr3proba::LearnerSurv,

  public = list(
    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    initialize = function() {
      ps = ps(
          alpha = p_dbl(default = 0.5, tags = "train"),
          ntree = p_int(default = 100L, lower = 1L, tags = "train"),
          eval_times = p_uty(tags = "train"),
          min_events_to_split_node = p_int(default = 5L, lower = 1L, tags = "train"),
          min_obs_to_split_node = p_int(default = 10L, lower = 1L, tags = "train"),
          min_obs_in_leaf_node = p_int(default = 5L, lower = 1L, tags = "train"),
          min_events_in_leaf_node = p_int(default = 1L, lower = 1L, tags = "train"),
          nsplit = p_int(default = 25L, lower = 1, tags = "train"),
          gamma = p_dbl(default = 0.5, lower = 1e-16, tags = "train"),
          max_pval_to_split_node = p_dbl(lower = 0, upper = 1, default = 0.5,
            tags = "train"),
          mtry = p_int(lower = 1, tags = "train"),
          dfmax = p_int(lower = 1, tags = "train"),
          use.cv = p_lgl(default = FALSE, tags = "train"),
          verbose = p_lgl(default = TRUE, tags = "train"),
          compute_oob_predictions = p_lgl(default = FALSE, tags = "train"),
          random_seed = p_int(tags = "train")
      )

      ps$values = list(verbose = FALSE)

      super$initialize(
        id = "surv.obliqueRSF",
        packages = c("obliqueRSF", "pracma"),
        feature_types = c("integer", "numeric", "factor", "ordered"),
        predict_types = c("crank", "distr"),
        param_set = ps,
        properties = c("missings", "oob_error"),
        man = "mlr3extralearners::mlr_learners_surv.obliqueRSF"
      )
    },


    #' @description
    #' Integrated brier score OOB error extracted from the model slot `oob_error`.
    #' Concordance is also available.
    #' @return `numeric()`.
    oob_error = function() {
      self$model$oob_error$integrated_briscr[2, ]
    }

  ),

  private = list(
    .train = function(task) {
      pv = self$param_set$get_values(tags = "train")
      targets = task$target_names

      mlr3misc::invoke(
        obliqueRSF::ORSF,
        data     = as.data.frame(task$data()),
        time     = targets[1L],
        status   = targets[2L],
        .args    = pv
      )
    },

    .predict = function(task) {

      time = self$model$data[[task$target_names[1]]]
      status = self$model$data[[task$target_names[2]]]
      utime = unique(time[status == 1])

      surv = mlr3misc::invoke(predict,
                              self$model,
                              newdata = task$data(cols = task$feature_names),
                              times = utime,
                              .args = self$param_set$get_values(tags = "predict"))

      mlr3proba::.surv_return(times = utime, surv = surv)
    }
  )
)

.extralrns_dict$add("surv.obliqueRSF", LearnerSurvObliqueRSF)
