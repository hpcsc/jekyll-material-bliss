//var StaticSiteGeneratorPlugin = require('static-site-generator-webpack-plugin');
var webpack = require('webpack');
var path = require('path');
var BundleAnalyzerPlugin = require('webpack-bundle-analyzer').BundleAnalyzerPlugin;

module.exports = {
  entry: './react-dev/router.js',

  //devtool: 'cheap-module-source-map',
  devtool: 'eval',
  // webpack folder's entry js - excluded from jekll's build process.

  output: {
    // we're going to put the generated file in the assets folder so jekyll will grab it.
    filename: 'bundle.js',
    path: path.resolve('public/assets/js/'),
    //need to compile to UMD or CommonJS so it can be requred in a Node context
  },
  module: {
    rules: [
      {
        test: /\.jsx?$/,
        exclude: /(node_modules)/,
        loader: 'babel-loader', // 'babel-loader' is also a legal name to reference
        query: {
          presets: ['react', 'es2015', 'stage-1']
        }
      },
      {
        test: /\.json$/,
        loader: 'json-loader'
      },
      {
        test: /\.css$/,
        loader: 'style!css?modules',
        include: /flexboxgrid/,
      },
    ],
  },
  resolve: {
    extensions: ['.js', '.jsx']
  },
  devServer: {
    historyApiFallback: true,
    contentBase: './react-dev/'
  },
  plugins: [
    new webpack.DefinePlugin({
      'process.env.NODE_ENV': '"development"'
    }),
    new BundleAnalyzerPlugin({
      analyzerMode: 'server',
      analyzerPort: 8880
    })
  ],
  node: {
    console: true,
    fs: 'empty'
  }
};
