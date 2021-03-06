#' Add marginal density/histogram to ggplot2 scatterplots
#'
#' Create a ggplot2 scatterplot with marginal density plots (default) or
#' histograms, or add the marginal plots to an existing scatterplot.
#'
#' @note The \code{grid} and \code{gtable} packages are required for this
#' function.
#' @param p A ggplot2 scatterplot to add marginal plots to.  If \code{p} is
#' not provided, then all of \code{data}, \code{x}, and \code{y} must be
#' provided.
#' @param data The data.frame to use for creating the marginal plots. Optional
#' if \code{p} is provided and the marginal plots are reflecting the same data.
#' @param x The name of the variable along the x axis. Optional if \code{p} is
#' provided and the \code{x} aesthetic is set in the main plot.
#' @param y The name of the variable along the y axis. Optional if \code{p} is
#' provided and the \code{y} aesthetic is set in the main plot.
#' @param type What type of marginal plot to show. One of: [density, histogram, boxplot, violin].
#' @param margins Along which margins to show the plots. One of: [both, x, y].
#' @param size Integer describing the relative size of the marginal plots
#' compared to the main plot. A size of 5 means that the main plot is 5x wider
#' and 5x taller than the marginal plots.
#' @param ... Extra parameters to pass to the marginal plots. Any parameter that
#' \code{geom_line()}, \code{geom_histogram()}, \code{geom_boxplot()}, or \code{geom_violin()} accepts
#' can be used. For example, \code{colour = "red"} can be used for any marginal plot type,
#' and \code{binwidth = 10} can be used for histograms.
#' @param xparams List of extra parameters to use only for the marginal plot along
#' the x axis.
#' @param yparams List of extra parameters to use only for the marginal plot along
#' the y axis.
#' @return An object of class \code{ggExtraPlot}. This object can be printed to show the
#' plots or saved using any of the typical image-saving functions (for example, using
#' \code{png()} or \code{pdf()}).
#' @note Since the \code{size} parameter is used by \code{ggMarginal}, if you want
#' to pass a size to the marginal plots, you cannot
#' use the \code{...} parameter. Instead, you must pass \code{size} to
#' both \code{xparams} and \code{yparams}. For example,
#' \code{ggMarginal(p, size = 2)} will change the size of the main vs marginal plot,
#' while \code{ggMarginal(p, xparams = list(size=2), yparams = list(size=2))}
#' will make the density plot outline thicker.
#' @examples
#'
#' # basic usage
#' p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
#' ggMarginal(p)
#'
#' # using some parameters
#' set.seed(30)
#' df <- data.frame(x = rnorm(500, 50, 10), y = runif(500, 0, 50))
#' p2 <- ggplot2::ggplot(df, ggplot2::aes(x, y)) + ggplot2::geom_point()
#' ggMarginal(p2)
#' ggMarginal(p2, type = "histogram")
#' ggMarginal(p2, margins = "x")
#' ggMarginal(p2, size = 2)
#' ggMarginal(p2, colour = "red")
#' ggMarginal(p2, colour = "red", xparams = list(colour = "blue", size = 3))
#' ggMarginal(p2, type = "histogram", bins = 10)
#'
#' # Using violin plot
#' ggMarginal(p2, type = "violin")
#'
#' # specifying the data directly instead of providing a plot
#' ggMarginal(data = df, x = "x", y = "y")
#'
#' # more examples showing how the marginal plots are properly aligned even when
#' # the main plot axis/margins/size/etc are changed
#' set.seed(30)
#' df2 <- data.frame(x = c(rnorm(250, 50, 10), rnorm(250, 100, 10)),
#'                   y = runif(500, 0, 50))
#' p2 <- ggplot2::ggplot(df2, ggplot2::aes(x, y)) + ggplot2::geom_point()
#' ggMarginal(p2)
#'
#' p2 <- p2 + ggplot2::ggtitle("Random data") + ggplot2::theme_bw(30)
#' ggMarginal(p2)
#'
#' p3 <- ggplot2::ggplot(df2, ggplot2::aes(log(x), y - 500)) + ggplot2::geom_point()
#' ggMarginal(p3)
#'
#' p4 <- p3 + ggplot2::scale_x_continuous(limits = c(2, 6)) + ggplot2::theme_bw(50)
#' ggMarginal(p4)
#' @seealso \href{http://daattali.com/shiny/ggExtra-ggMarginal-demo/}{Demo Shiny app}
#' @export
ggMarginal <- function(p, data, x, y, type = c("density", "histogram", "boxplot", "violin"),
                       margins = c("both", "x", "y"), size = 5,
                       ..., xparams = list(), yparams = list()) {

  # Figure out all the default parameters.
  type <- match.arg(type)
  margins <- match.arg(margins)

  # Fill in param defaults and consolidate params into single list (prmL).
  prmL <- toParamList(exPrm = list(...), xPrm = xparams, yPrm = yparams)

  # After ggplot2 v1.0.1, layers became strict about parameters
  if (type == "density") {
    prmL[['exPrm']][['fill']] <- NULL
  }

  # Create one version of the scat plot (scatP), based on values of p, data, x,
  # and y...also remove all margin around plot so that it's easier to position
  # the density plots beside the main plot
  scatP <- reconcileScatPlot(p = p, data = data, x = x, y = y) +
    ggplot2::theme(plot.margin = grid::unit(c(0, 0, .25, .25), "cm"))

  # Decompose scatP to grab all sorts of information from it
  scatPbuilt <- ggplot2::ggplot_build(scatP)

  # Pull out the plot title if one exists and save it as a grob for later use.
  hasTitle <- (!is.null(scatPbuilt$plot$labels$title))
  if (hasTitle) {
    titleGrobs <- getTitleGrobs(p = p)
    scatP$labels$title <- NULL
    scatP$labels$subtitle <- NULL
  }

  # Create the margin plots by calling genFinalMargPlot
  # In order to ensure the marginal plots line up nicely with the main plot,
  # several things are done:
    # - Use the same label text size as the original
    # - Remove the margins from all plots
    # - Make all text in marginal plots transparent
    # - Remove all lines and colours from marginal plots
    # - Use the same axis range as the main plot

  # If margins = x or 'both' (x and y), then you have to create top plot
  # Top plot = horizontal margin plot, which corresponds to x marg
  if (margins != "y") {
    top <- genFinalMargPlot(marg = "x", type = type, scatPbuilt = scatPbuilt,
                            prmL = prmL)
  }

  # If margins = y or 'both' (x and y), then you have to create right plot.
  # (right plot = vertical margin plot, which corresponds to y marg)
  if (margins != "x") {
    right <- genFinalMargPlot(marg = "y", type = type, scatPbuilt = scatPbuilt,
                              prmL = prmL)
  }

  # Now add the marginal plots to the scatter plot
  pGrob <- ggplot2::ggplotGrob(scatP)

  withCallingHandlers({
    suppressMessages({
      if (margins == "both") {
        ggxtraTmp <- addTopMargPlot(ggMargGrob = pGrob, top = top, size = size)
        ggxtraNoTtl <- addRightMargPlot(ggMargGrob = ggxtraTmp, right = right,
                                        size = size)
      } else if (margins == "x") {
        ggxtraTmp <- gtable::gtable_add_padding(x = pGrob,
                                                grid::unit(c(0, 0.5, 0, 0),
                                                           "lines"))
        ggxtraNoTtl <- addTopMargPlot(ggMargGrob = ggxtraTmp, top = top,
                                      size = size)
      } else if (margins == "y") {
        ggxtraTmp <- gtable::gtable_add_padding(x = pGrob,
                                                grid::unit(c(0.5, 0, 0, 0),
                                                           "lines"))
        ggxtraNoTtl <- addRightMargPlot(ggMargGrob = ggxtraTmp, right = right,
                                        size = size)
      }
    })
  }, warning = function(w) {
    if (grepl("did you forget aes", w, ignore.case = TRUE))
      invokeRestart("muffleWarning")
  })

  # Add the title to the resulting ggExtra plot if it exists
  if (hasTitle) {
    ggExtraPlot <- addTitleGrobs(ggxtraNoTtl = ggxtraNoTtl,
                                 titleGrobs = titleGrobs)
  } else {
    ggExtraPlot <- ggxtraNoTtl
  }
  # Add a class for S3 method dispatch for printing the ggExtra plot
  class(ggExtraPlot) <- c("ggExtraPlot", class(ggExtraPlot))
  ggExtraPlot
}

#' Print a ggExtraPlot object
#'
#' \code{ggExtraPlot} objects are created from \code{ggMarginal}. This is the S3
#' generic print method to print the result of the scatterplot with its marginal
#' plots.
#'
#' @param x ggExtraPlot object.
#' @param newpage Should a new page (i.e., an empty page) be drawn before the
#' ggExtraPlot is drawn?
#' @param ... ignored
#' @seealso \code{\link{ggMarginal}}
#' @export
#' @keywords internal
print.ggExtraPlot <- function(x, newpage = grDevices::dev.interactive(), ...) {
  if (newpage) grid::grid.newpage()
  grid::grid.draw(x)
}
