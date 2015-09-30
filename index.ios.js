'use strict'

var React = require('react-native')
var PropTypes = require('ReactPropTypes')
var ReactNativeViewAttributes = require('ReactNativeViewAttributes')
var createReactNativeComponentClass = require('createReactNativeComponentClass')
var NativeMethodsMixin = require('NativeMethodsMixin')
var _ = require("underscore")

var { View, requireNativeComponent, PropTypes, NativeModules } = React

var CHART_REF = 'chart'

var Chart = React.createClass({

  propTypes: {
    chartData: PropTypes.object,
    chartPoints: PropTypes.array,
    moments: PropTypes.array,
    activeMomentIndex: PropTypes.number,
    homeTeamName: PropTypes.string,
    awayTeamName: PropTypes.string,
    lineWidth: PropTypes.number,
    smoothingBuffer: PropTypes.number,
    homeTeamColor: PropTypes.string,
    awayTeamColor: PropTypes.string,
    onTouchStarted: PropTypes.func,
    onTouchEnded: PropTypes.func
  },

  getInitialState() {
    return {
      chartPoints: {
        xCoords: [],
        yCoords: [],
      }
    }
  },

  getDefaultProps() {
    return {
      onTouchStarted: () => {},
      onTouchEnded: () => {},
      smoothingBuffer: 100, //in seconds
    }
  },

  componentWillReceiveProps(nextProps) {
    if(nextProps.chartPoints != []) {
      var cleanedPoints = this._dataCoordinateCleanup(nextProps.chartPoints)
      this.setState({
        chartPoints: cleanedPoints
      })
    }
  },

  setNativeProps(props) {
    this.refs[CHART_REF].setNativeProps(props)
  },

  _dataCoordinateCleanup(chartData) {
    var xVals = _.map(chartData, function(chartPoint) {
      return chartPoint.timestamp
    })

    var yVals = _.map(chartData, function(chartPoint) {
      return (chartPoint.homeTeamScore - chartPoint.awayTeamScore)
    })

    var xCoords = []
    var yCoords = []
    var cleanedXCoords = []
    var cleanedYCoords = []


    xCoords.push(xVals[0])
    yCoords.push(yVals[0])

    for (var i = 1; i < yVals.length; i++) {
      if (yVals[i] != yVals[i-1]) {
        if ((xVals[i] - this.props.smoothingBuffer) > xCoords[xCoords.length - 1]) {
          xCoords.push(xVals[i] - this.props.smoothingBuffer)
          yCoords.push(yVals[i - 1])
        }
        xCoords.push(xVals[i])
        yCoords.push(yVals[i])
      }
    }
    xCoords.push(xVals[xVals.length - 1])
    yCoords.push(yVals[yVals.length - 1])

    //make extra points same data point as touchdown - makes chart look smoother
    for (var i = 0; i < xCoords.length - 1; i++){
      if ((yCoords[i+1] == yCoords[i] + 1) || (yCoords[i+1] == yCoords[i] - 1)){
        i++
      }
      cleanedXCoords.push(xCoords[i])
      cleanedYCoords.push(yCoords[i])
    }
    cleanedXCoords.push(xCoords[xCoords.length - 1])
    cleanedYCoords.push(yCoords[yCoords.length - 1])

    return {xCoords: cleanedXCoords, yCoords: cleanedYCoords}
  },

  render() {

    var nativeProps = Object.assign({},this.props, {
      style: this.props.style,
      backgroundColor: this.props.style.backgroundColor
    })

    return (
        <SwishGameflowChart
          {... nativeProps}
          ref={CHART_REF}
          chartData={this.state.chartPoints} />
    )
  }
})

var SwishGameflowChart = requireNativeComponent('SwishGameflowChart', Chart)

module.exports = Chart
