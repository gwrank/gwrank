/*!-----------------------------------------------------------------
    Name: MonsterPlay - eSports and Gaming HTML Template
    Version: 1.0.3
    Author: nK
    Website: https://nkdev.info/
    Purchase: https://themeforest.net/user/_nk/portfolio
    Support: https://nk.ticksy.com/
    License: You must have a valid license purchased only from ThemeForest (the above link) in order to legally use the theme for your project.
    Copyright 2020.
-------------------------------------------------------------------*/
    /******/ (function(modules) { // webpackBootstrap
/******/ 	// The module cache
/******/ 	var installedModules = {};
/******/
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/
/******/ 		// Check if module is in cache
/******/ 		if(installedModules[moduleId]) {
/******/ 			return installedModules[moduleId].exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = installedModules[moduleId] = {
/******/ 			i: moduleId,
/******/ 			l: false,
/******/ 			exports: {}
/******/ 		};
/******/
/******/ 		// Execute the module function
/******/ 		modules[moduleId].call(module.exports, module, module.exports, __webpack_require__);
/******/
/******/ 		// Flag the module as loaded
/******/ 		module.l = true;
/******/
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/
/******/
/******/ 	// expose the modules object (__webpack_modules__)
/******/ 	__webpack_require__.m = modules;
/******/
/******/ 	// expose the module cache
/******/ 	__webpack_require__.c = installedModules;
/******/
/******/ 	// define getter function for harmony exports
/******/ 	__webpack_require__.d = function(exports, name, getter) {
/******/ 		if(!__webpack_require__.o(exports, name)) {
/******/ 			Object.defineProperty(exports, name, { enumerable: true, get: getter });
/******/ 		}
/******/ 	};
/******/
/******/ 	// define __esModule on exports
/******/ 	__webpack_require__.r = function(exports) {
/******/ 		if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 			Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 		}
/******/ 		Object.defineProperty(exports, '__esModule', { value: true });
/******/ 	};
/******/
/******/ 	// create a fake namespace object
/******/ 	// mode & 1: value is a module id, require it
/******/ 	// mode & 2: merge all properties of value into the ns
/******/ 	// mode & 4: return value when already ns object
/******/ 	// mode & 8|1: behave like require
/******/ 	__webpack_require__.t = function(value, mode) {
/******/ 		if(mode & 1) value = __webpack_require__(value);
/******/ 		if(mode & 8) return value;
/******/ 		if((mode & 4) && typeof value === 'object' && value && value.__esModule) return value;
/******/ 		var ns = Object.create(null);
/******/ 		__webpack_require__.r(ns);
/******/ 		Object.defineProperty(ns, 'default', { enumerable: true, value: value });
/******/ 		if(mode & 2 && typeof value != 'string') for(var key in value) __webpack_require__.d(ns, key, function(key) { return value[key]; }.bind(null, key));
/******/ 		return ns;
/******/ 	};
/******/
/******/ 	// getDefaultExport function for compatibility with non-harmony modules
/******/ 	__webpack_require__.n = function(module) {
/******/ 		var getter = module && module.__esModule ?
/******/ 			function getDefault() { return module['default']; } :
/******/ 			function getModuleExports() { return module; };
/******/ 		__webpack_require__.d(getter, 'a', getter);
/******/ 		return getter;
/******/ 	};
/******/
/******/ 	// Object.prototype.hasOwnProperty.call
/******/ 	__webpack_require__.o = function(object, property) { return Object.prototype.hasOwnProperty.call(object, property); };
/******/
/******/ 	// __webpack_public_path__
/******/ 	__webpack_require__.p = "";
/******/
/******/
/******/ 	// Load entry module and return exports
/******/ 	return __webpack_require__(__webpack_require__.s = 3);
/******/ })
/************************************************************************/
/******/ ([
/* 0 */,
/* 1 */,
/* 2 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "options", function() { return options; });
/*------------------------------------------------------------------

  Theme Options

-------------------------------------------------------------------*/
// eslint-disable-next-line max-len
var instagramIcon = '<svg class="icon" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M17.5 6.5H17.51M7 2H17C19.7614 2 22 4.23858 22 7V17C22 19.7614 19.7614 22 17 22H7C4.23858 22 2 19.7614 2 17V7C2 4.23858 4.23858 2 7 2ZM16 11.37C16.1234 12.2022 15.9813 13.0522 15.5938 13.799C15.2063 14.5458 14.5931 15.1514 13.8416 15.5297C13.0901 15.9079 12.2384 16.0396 11.4078 15.9059C10.5771 15.7723 9.80976 15.3801 9.21484 14.7852C8.61992 14.1902 8.22773 13.4229 8.09407 12.5922C7.9604 11.7616 8.09207 10.9099 8.47033 10.1584C8.84859 9.40685 9.45419 8.79374 10.201 8.40624C10.9478 8.01874 11.7978 7.87659 12.63 8C13.4789 8.12588 14.2649 8.52146 14.8717 9.12831C15.4785 9.73515 15.8741 10.5211 16 11.37Z"/></svg>';
var options = {
  // enable cursor
  customCursor: true,
  // enable parallax
  parallax: true,
  // set small navbar on load
  navbarSmall: false,
  // set small navbar on scroll
  navbarSmallMaxTop: 100,
  // twitter and instagram php paths
  php: {
    twitter: './php/twitter/tweet.php',
    instagram: './php/instagram/instagram.php'
  },
  templates: {
    instagram: "<a class=\"mpl-instagram-item\" href=\"{{link}}\" target=\"_blank\">\n                <span class=\"mpl-instagram-overlay\">\n                    ".concat(instagramIcon, "\n                </span>\n                <img src=\"{{image}}\" alt=\"{{caption}}\">\n            </a>"),
    instagramLoadingText: 'Loading...',
    instagramFailText: 'Failed to fetch data',
    twitter: "<div>\n               <div class=\"mpl-twitter-head\">\n                   <div class=\"mpl-twitter-avatar\">\n                       {{avatar}}\n                   </div>\n                   <a href=\"{{url}}\" class=\"mpl-twitter-name\">\n                       {{user_name}}\n                   </a>\n                   <div class=\"mpl-twitter-date date\">\n                       <span>{{date}}</span>\n                   </div>\n               </div>\n               <div class=\"mpl-twitter-text\">\n                  {{tweet}}\n               </div>\n            </div>",
    twitterLoadingText: 'Loading...',
    twitterFailText: 'Failed to fetch data'
  }
};


/***/ }),
/* 3 */
/***/ (function(module, exports, __webpack_require__) {

module.exports = __webpack_require__(4);


/***/ }),
/* 4 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony import */ var _parts_options__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(2);
/* harmony import */ var _parts_utility__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(5);
/* harmony import */ var _parts_setOptions__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(7);
/* harmony import */ var _parts_initCursor__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(8);
/* harmony import */ var _parts_initNavbar__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(9);
/* harmony import */ var _parts_initAnchors__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(10);
/* harmony import */ var _parts_initForms__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(11);
/* harmony import */ var _parts_initHexagonRating__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(12);
/* harmony import */ var _parts_initTwitter__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(13);
/* harmony import */ var _parts_initFacebook__WEBPACK_IMPORTED_MODULE_9__ = __webpack_require__(14);
/* harmony import */ var _parts_initInstagram__WEBPACK_IMPORTED_MODULE_10__ = __webpack_require__(15);
/* harmony import */ var _parts_initPluginScrollReveal__WEBPACK_IMPORTED_MODULE_11__ = __webpack_require__(16);
/* harmony import */ var _parts_initPluginAnime__WEBPACK_IMPORTED_MODULE_12__ = __webpack_require__(17);
/* harmony import */ var _parts_initPluginObjectFitImages__WEBPACK_IMPORTED_MODULE_13__ = __webpack_require__(18);
/* harmony import */ var _parts_initPluginCountUp__WEBPACK_IMPORTED_MODULE_14__ = __webpack_require__(19);
/* harmony import */ var _parts_initPluginSwiper__WEBPACK_IMPORTED_MODULE_15__ = __webpack_require__(21);
/* harmony import */ var _parts_initPluginSliderRevolution__WEBPACK_IMPORTED_MODULE_16__ = __webpack_require__(22);
/* harmony import */ var _parts_initPluginIsotope__WEBPACK_IMPORTED_MODULE_17__ = __webpack_require__(23);
/* harmony import */ var _parts_initPluginTouchSpin__WEBPACK_IMPORTED_MODULE_18__ = __webpack_require__(24);
/* harmony import */ var _parts_initPluginFancybox__WEBPACK_IMPORTED_MODULE_19__ = __webpack_require__(25);
/* harmony import */ var _parts_initPluginRangeslider__WEBPACK_IMPORTED_MODULE_20__ = __webpack_require__(26);
/* harmony import */ var _parts_initPluginJarallax__WEBPACK_IMPORTED_MODULE_21__ = __webpack_require__(27);
function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

function _defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } }

function _createClass(Constructor, protoProps, staticProps) { if (protoProps) _defineProperties(Constructor.prototype, protoProps); if (staticProps) _defineProperties(Constructor, staticProps); return Constructor; }























/*------------------------------------------------------------------

  MonsterPlay Class

-------------------------------------------------------------------*/

var MONSTERPLAY = /*#__PURE__*/function () {
  function MONSTERPLAY() {
    _classCallCheck(this, MONSTERPLAY);

    this.options = _parts_options__WEBPACK_IMPORTED_MODULE_0__["options"];
  }

  _createClass(MONSTERPLAY, [{
    key: "init",
    value: function init() {
      // prt:sc:dm
      var self = this;
      self.initCursor();
      self.initNavbar();
      self.initAnchors();
      self.initForms();
      self.initHexagonRating();
      self.initTwitter();
      self.initFacebook();
      self.initInstagram(); // init plugins

      self.initPluginScrollReveal();
      self.initPluginAnime();
      self.initPluginObjectFitImages();
      self.initPluginCountUp();
      self.initPluginSwiper();
      self.initPluginSliderRevolution();
      self.initPluginIsotope();
      self.initPluginTouchSpin();
      self.initPluginFancybox();
      self.initPluginRangeslider();
      self.initPluginJarallax();
      $('[data-toggle="tooltip"]').tooltip();
      $('[data-toggle="popover"]').popover();
      return self;
    }
  }, {
    key: "setOptions",
    value: function setOptions(newOpts) {
      return _parts_setOptions__WEBPACK_IMPORTED_MODULE_2__["setOptions"].call(this, newOpts);
    }
  }, {
    key: "debounceResize",
    value: function debounceResize(func) {
      return _parts_utility__WEBPACK_IMPORTED_MODULE_1__["debounceResize"].call(this, func);
    }
  }, {
    key: "throttleScroll",
    value: function throttleScroll(callback) {
      return _parts_utility__WEBPACK_IMPORTED_MODULE_1__["throttleScroll"].call(this, callback);
    }
  }, {
    key: "bodyOverflow",
    value: function bodyOverflow(type) {
      return _parts_utility__WEBPACK_IMPORTED_MODULE_1__["bodyOverflow"].call(this, type);
    }
  }, {
    key: "isInViewport",
    value: function isInViewport($item, returnRect) {
      return _parts_utility__WEBPACK_IMPORTED_MODULE_1__["isInViewport"].call(this, $item, returnRect);
    }
  }, {
    key: "scrollTo",
    value: function scrollTo($to, callback) {
      return _parts_utility__WEBPACK_IMPORTED_MODULE_1__["scrollTo"].call(this, $to, callback);
    }
  }, {
    key: "initCursor",
    value: function initCursor() {
      return _parts_initCursor__WEBPACK_IMPORTED_MODULE_3__["initCursor"].call(this);
    }
  }, {
    key: "initNavbar",
    value: function initNavbar() {
      return _parts_initNavbar__WEBPACK_IMPORTED_MODULE_4__["initNavbar"].call(this);
    }
  }, {
    key: "initAnchors",
    value: function initAnchors() {
      return _parts_initAnchors__WEBPACK_IMPORTED_MODULE_5__["initAnchors"].call(this);
    }
  }, {
    key: "initForms",
    value: function initForms() {
      return _parts_initForms__WEBPACK_IMPORTED_MODULE_6__["initForms"].call(this);
    }
  }, {
    key: "initHexagonRating",
    value: function initHexagonRating() {
      return _parts_initHexagonRating__WEBPACK_IMPORTED_MODULE_7__["initHexagonRating"].call(this);
    }
  }, {
    key: "initTwitter",
    value: function initTwitter() {
      return _parts_initTwitter__WEBPACK_IMPORTED_MODULE_8__["initTwitter"].call(this);
    }
  }, {
    key: "initFacebook",
    value: function initFacebook() {
      return _parts_initFacebook__WEBPACK_IMPORTED_MODULE_9__["initFacebook"].call(this);
    }
  }, {
    key: "initInstagram",
    value: function initInstagram() {
      return _parts_initInstagram__WEBPACK_IMPORTED_MODULE_10__["initInstagram"].call(this);
    }
  }, {
    key: "initPluginScrollReveal",
    value: function initPluginScrollReveal() {
      return _parts_initPluginScrollReveal__WEBPACK_IMPORTED_MODULE_11__["initPluginScrollReveal"].call(this);
    }
  }, {
    key: "initPluginAnime",
    value: function initPluginAnime() {
      return _parts_initPluginAnime__WEBPACK_IMPORTED_MODULE_12__["initPluginAnime"].call(this);
    }
  }, {
    key: "initPluginObjectFitImages",
    value: function initPluginObjectFitImages() {
      return _parts_initPluginObjectFitImages__WEBPACK_IMPORTED_MODULE_13__["initPluginObjectFitImages"].call(this);
    }
  }, {
    key: "initPluginCountUp",
    value: function initPluginCountUp() {
      return _parts_initPluginCountUp__WEBPACK_IMPORTED_MODULE_14__["initPluginCountUp"].call(this);
    }
  }, {
    key: "initPluginSwiper",
    value: function initPluginSwiper() {
      return _parts_initPluginSwiper__WEBPACK_IMPORTED_MODULE_15__["initPluginSwiper"].call(this);
    }
  }, {
    key: "initPluginSliderRevolution",
    value: function initPluginSliderRevolution() {
      return _parts_initPluginSliderRevolution__WEBPACK_IMPORTED_MODULE_16__["initPluginSliderRevolution"].call(this);
    }
  }, {
    key: "initPluginIsotope",
    value: function initPluginIsotope() {
      return _parts_initPluginIsotope__WEBPACK_IMPORTED_MODULE_17__["initPluginIsotope"].call(this);
    }
  }, {
    key: "initPluginTouchSpin",
    value: function initPluginTouchSpin() {
      return _parts_initPluginTouchSpin__WEBPACK_IMPORTED_MODULE_18__["initPluginTouchSpin"].call(this);
    }
  }, {
    key: "initPluginFancybox",
    value: function initPluginFancybox() {
      return _parts_initPluginFancybox__WEBPACK_IMPORTED_MODULE_19__["initPluginFancybox"].call(this);
    }
  }, {
    key: "initPluginRangeslider",
    value: function initPluginRangeslider() {
      return _parts_initPluginRangeslider__WEBPACK_IMPORTED_MODULE_20__["initPluginRangeslider"].call(this);
    }
  }, {
    key: "initPluginJarallax",
    value: function initPluginJarallax() {
      return _parts_initPluginJarallax__WEBPACK_IMPORTED_MODULE_21__["initPluginJarallax"].call(this);
    }
  }]);

  return MONSTERPLAY;
}();
/*------------------------------------------------------------------

  Init MonsterPlay

-------------------------------------------------------------------*/


window.MonsterPlay = new MONSTERPLAY();

/***/ }),
/* 5 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "$", function() { return $; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "tween", function() { return tween; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "isIOs", function() { return isIOs; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "isMobile", function() { return isMobile; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "isTouch", function() { return isTouch; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "$wnd", function() { return $wnd; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "$doc", function() { return $doc; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "$body", function() { return $body; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "wndW", function() { return wndW; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "wndH", function() { return wndH; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "docH", function() { return docH; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "debounceResize", function() { return debounceResize; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "throttleScroll", function() { return throttleScroll; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "bodyOverflow", function() { return bodyOverflow; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "scrollbarWidth", function() { return scrollbarWidth; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "isBodyOverflowed", function() { return isBodyOverflowed; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "isInViewport", function() { return isInViewport; });
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "scrollTo", function() { return scrollTo; });
/* harmony import */ var throttle_debounce__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(6);
/* harmony import */ var throttle_debounce__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(throttle_debounce__WEBPACK_IMPORTED_MODULE_0__);
/*------------------------------------------------------------------

  Utility

-------------------------------------------------------------------*/

var $ = window.jQuery;
var tween = window.TweenMax;
var isIOs = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;
var isMobile = /Android|iPhone|iPad|iPod|BlackBerry|Windows Phone/g.test(navigator.userAgent || navigator.vendor || window.opera);
var isTouch = 'ontouchstart' in window || window.DocumentTouch && document instanceof DocumentTouch;
/**
 * window size
 */

var $wnd = $(window);
var $doc = $(document);
var $body = $('body');
var $html = $('html');
var wndW = 0;
var wndH = 0;
var docH = 0;

function getWndSize() {
  wndW = $wnd.width();
  wndH = $wnd.height();
  docH = $doc.height();
}

getWndSize();
$wnd.on('resize load orientationchange', getWndSize); // add 'is-mobile' or 'is-desktop' classname to html tag

$html.addClass(isMobile ? 'is-mobile' : 'is-desktop');
/**
 * Debounce resize
 */

var resizeArr = [];

function debounceResized() {
  if (resizeArr.length) {
    for (var k = 0; k < resizeArr.length; k++) {
      resizeArr[k]();
    }
  }
}

$wnd.on('ready load resize orientationchange', Object(throttle_debounce__WEBPACK_IMPORTED_MODULE_0__["throttle"])(200, function () {
  window.requestAnimationFrame(debounceResized);
}));
debounceResized();

function debounceResize(func) {
  if (typeof func === 'function') {
    resizeArr.push(func);
  } else {
    window.dispatchEvent(new Event('resize'));
  }
}
/**
 * Throttle scroll
 */


var hideOnScrollList = [];
var lastST = 0;

function hasScrolled() {
  var ST = $wnd.scrollTop();
  var type = ''; // [up, down, end, start]

  if (ST > lastST) {
    type = 'down';
  } else if (ST < lastST) {
    type = 'up';
  } else {
    type = 'none';
  }

  if (ST === 0) {
    type = 'start';
  } else if (ST >= docH - wndH) {
    type = 'end';
  }

  hideOnScrollList.forEach(function (value) {
    if (typeof value === 'function') {
      value(type, ST, lastST, $wnd);
    }
  });
  lastST = ST;
}

$wnd.on('scroll ready load resize orientationchange', Object(throttle_debounce__WEBPACK_IMPORTED_MODULE_0__["throttle"])(200, function () {
  if (hideOnScrollList.length) {
    window.requestAnimationFrame(hasScrolled);
  }
}));

function throttleScroll(callback) {
  hideOnScrollList.push(callback);
}
/**
 * Body Overflow
 * Thanks https://jsfiddle.net/mariusc23/s6mLJ/31/
 * Usage:
 *    // enable
 *    bodyOverflow(1);
 *
 *    // disable
 *    bodyOverflow(0);
 */


var bodyOverflowEnabled;
var isBodyOverflowing;
var scrollbarWidth;
var originalBodyStyle;
var $navbarTop = $('.mpl-navbar');
var stopOverflowing = $('.page-full').length;
var originalBodyPadding = parseFloat($body.css('padding-right')) || 0;

function isBodyOverflowed() {
  return bodyOverflowEnabled;
}

function bodyGetScrollbarWidth() {
  // thx d.walsh
  var scrollDiv = document.createElement('div');
  scrollDiv.className = 'body-scrollbar-measure';
  $body[0].appendChild(scrollDiv);
  var result = scrollDiv.offsetWidth - scrollDiv.clientWidth;
  $body[0].removeChild(scrollDiv);
  return result;
}

function bodyCheckScrollbar() {
  var fullWindowWidth = window.innerWidth;

  if (!fullWindowWidth) {
    // workaround for missing window.innerWidth in IE8
    var documentElementRect = document.documentElement.getBoundingClientRect();
    fullWindowWidth = documentElementRect.right - Math.abs(documentElementRect.left);
  }

  isBodyOverflowing = $body[0].clientWidth < fullWindowWidth;
  scrollbarWidth = bodyGetScrollbarWidth();
}

function bodySetScrollbar() {
  if (typeof originalBodyStyle === 'undefined') {
    originalBodyStyle = $body.attr('style') || '';
  }

  if (isBodyOverflowing) {
    $body.css('margin-right', scrollbarWidth + originalBodyPadding);
    $navbarTop.css('margin-right', scrollbarWidth + originalBodyPadding);
  }
}

function bodyResetScrollbar() {
  $body.attr('style', originalBodyStyle);
  $navbarTop.attr('style', '');
}

function bodyOverflow(enable) {
  if (stopOverflowing) {
    return;
  }

  if (enable && !bodyOverflowEnabled) {
    bodyOverflowEnabled = 1;
    bodyCheckScrollbar();
    bodySetScrollbar();
    $body.css('overflow', 'hidden');
  } else if (!enable && bodyOverflowEnabled) {
    bodyOverflowEnabled = 0;
    $body.css('overflow', '');
    bodyResetScrollbar();
  }
}
/**
 * In Viewport checker
 * return visible percent from 0 to 1
 */


function isInViewport($item, returnRect) {
  var rect = $item[0].getBoundingClientRect();
  var result = 1;

  if (rect.right <= 0 || rect.left >= wndW) {
    result = 0;
  } else if (rect.bottom < 0 && rect.top <= wndH) {
    result = 0;
  } else {
    var beforeTopEnd = Math.max(0, rect.height + rect.top);
    var beforeBottomEnd = Math.max(0, rect.height - (rect.top + rect.height - wndH));
    var afterTop = Math.max(0, -rect.top);
    var beforeBottom = Math.max(0, rect.top + rect.height - wndH);

    if (rect.height < wndH) {
      result = 1 - (afterTop || beforeBottom) / rect.height;
    } else if (beforeTopEnd <= wndH) {
      result = beforeTopEnd / wndH;
    } else if (beforeBottomEnd <= wndH) {
      result = beforeBottomEnd / wndH;
    }

    result = result < 0 ? 0 : result;
  }

  if (returnRect) {
    return [result, rect];
  }

  return result;
}
/**
 * Scroll To
 */


function scrollTo($to, callback) {
  var scrollPos = false;
  var speed = this.options.scrollToAnchorSpeed / 1000;

  if ($to === 'top') {
    scrollPos = 0;
  } else if ($to === 'bottom') {
    scrollPos = Math.max(0, docH - wndH);
  } else if (typeof $to === 'number') {
    scrollPos = $to;
  } else {
    scrollPos = $to.offset ? $to.offset().top : false;
  }

  if (scrollPos !== false && $wnd.scrollTop() !== scrollPos) {
    tween.to($wnd, speed, {
      scrollTo: {
        y: scrollPos,
        // disable autokill on iOs (buggy scrolling)
        autoKill: !isIOs
      },
      ease: Power2.easeOut,
      overwrite: 5
    });

    if (callback) {
      tween.delayedCall(speed, callback);
    }
  } else if (typeof callback === 'function') {
    callback();
  }
}



/***/ }),
/* 6 */
/***/ (function(module, exports, __webpack_require__) {

var __WEBPACK_AMD_DEFINE_FACTORY__, __WEBPACK_AMD_DEFINE_ARRAY__, __WEBPACK_AMD_DEFINE_RESULT__;function _typeof(obj) { "@babel/helpers - typeof"; if (typeof Symbol === "function" && typeof Symbol.iterator === "symbol") { _typeof = function _typeof(obj) { return typeof obj; }; } else { _typeof = function _typeof(obj) { return obj && typeof Symbol === "function" && obj.constructor === Symbol && obj !== Symbol.prototype ? "symbol" : typeof obj; }; } return _typeof(obj); }

(function (global, factory) {
  ( false ? undefined : _typeof(exports)) === 'object' && typeof module !== 'undefined' ? factory(exports) :  true ? !(__WEBPACK_AMD_DEFINE_ARRAY__ = [exports], __WEBPACK_AMD_DEFINE_FACTORY__ = (factory),
				__WEBPACK_AMD_DEFINE_RESULT__ = (typeof __WEBPACK_AMD_DEFINE_FACTORY__ === 'function' ?
				(__WEBPACK_AMD_DEFINE_FACTORY__.apply(exports, __WEBPACK_AMD_DEFINE_ARRAY__)) : __WEBPACK_AMD_DEFINE_FACTORY__),
				__WEBPACK_AMD_DEFINE_RESULT__ !== undefined && (module.exports = __WEBPACK_AMD_DEFINE_RESULT__)) : (undefined);
})(this, function (exports) {
  'use strict';
  /* eslint-disable no-undefined,no-param-reassign,no-shadow */

  /**
   * Throttle execution of a function. Especially useful for rate limiting
   * execution of handlers on events like resize and scroll.
   *
   * @param  {number}    delay -          A zero-or-greater delay in milliseconds. For event callbacks, values around 100 or 250 (or even higher) are most useful.
   * @param  {boolean}   [noTrailing] -   Optional, defaults to false. If noTrailing is true, callback will only execute every `delay` milliseconds while the
   *                                    throttled-function is being called. If noTrailing is false or unspecified, callback will be executed one final time
   *                                    after the last throttled-function call. (After the throttled-function has not been called for `delay` milliseconds,
   *                                    the internal counter is reset).
   * @param  {Function}  callback -       A function to be executed after delay milliseconds. The `this` context and all arguments are passed through, as-is,
   *                                    to `callback` when the throttled-function is executed.
   * @param  {boolean}   [debounceMode] - If `debounceMode` is true (at begin), schedule `clear` to execute after `delay` ms. If `debounceMode` is false (at end),
   *                                    schedule `callback` to execute after `delay` ms.
   *
   * @returns {Function}  A new, throttled, function.
   */

  function throttle(delay, noTrailing, callback, debounceMode) {
    /*
     * After wrapper has stopped being called, this timeout ensures that
     * `callback` is executed at the proper times in `throttle` and `end`
     * debounce modes.
     */
    var timeoutID;
    var cancelled = false; // Keep track of the last time `callback` was executed.

    var lastExec = 0; // Function to clear existing timeout

    function clearExistingTimeout() {
      if (timeoutID) {
        clearTimeout(timeoutID);
      }
    } // Function to cancel next exec


    function cancel() {
      clearExistingTimeout();
      cancelled = true;
    } // `noTrailing` defaults to falsy.


    if (typeof noTrailing !== 'boolean') {
      debounceMode = callback;
      callback = noTrailing;
      noTrailing = undefined;
    }
    /*
     * The `wrapper` function encapsulates all of the throttling / debouncing
     * functionality and when executed will limit the rate at which `callback`
     * is executed.
     */


    function wrapper() {
      for (var _len = arguments.length, arguments_ = new Array(_len), _key = 0; _key < _len; _key++) {
        arguments_[_key] = arguments[_key];
      }

      var self = this;
      var elapsed = Date.now() - lastExec;

      if (cancelled) {
        return;
      } // Execute `callback` and update the `lastExec` timestamp.


      function exec() {
        lastExec = Date.now();
        callback.apply(self, arguments_);
      }
      /*
       * If `debounceMode` is true (at begin) this is used to clear the flag
       * to allow future `callback` executions.
       */


      function clear() {
        timeoutID = undefined;
      }

      if (debounceMode && !timeoutID) {
        /*
         * Since `wrapper` is being called for the first time and
         * `debounceMode` is true (at begin), execute `callback`.
         */
        exec();
      }

      clearExistingTimeout();

      if (debounceMode === undefined && elapsed > delay) {
        /*
         * In throttle mode, if `delay` time has been exceeded, execute
         * `callback`.
         */
        exec();
      } else if (noTrailing !== true) {
        /*
         * In trailing throttle mode, since `delay` time has not been
         * exceeded, schedule `callback` to execute `delay` ms after most
         * recent execution.
         *
         * If `debounceMode` is true (at begin), schedule `clear` to execute
         * after `delay` ms.
         *
         * If `debounceMode` is false (at end), schedule `callback` to
         * execute after `delay` ms.
         */
        timeoutID = setTimeout(debounceMode ? clear : exec, debounceMode === undefined ? delay - elapsed : delay);
      }
    }

    wrapper.cancel = cancel; // Return the wrapper function.

    return wrapper;
  }
  /* eslint-disable no-undefined */

  /**
   * Debounce execution of a function. Debouncing, unlike throttling,
   * guarantees that a function is only executed a single time, either at the
   * very beginning of a series of calls, or at the very end.
   *
   * @param  {number}   delay -         A zero-or-greater delay in milliseconds. For event callbacks, values around 100 or 250 (or even higher) are most useful.
   * @param  {boolean}  [atBegin] -     Optional, defaults to false. If atBegin is false or unspecified, callback will only be executed `delay` milliseconds
   *                                  after the last debounced-function call. If atBegin is true, callback will be executed only at the first debounced-function call.
   *                                  (After the throttled-function has not been called for `delay` milliseconds, the internal counter is reset).
   * @param  {Function} callback -      A function to be executed after delay milliseconds. The `this` context and all arguments are passed through, as-is,
   *                                  to `callback` when the debounced-function is executed.
   *
   * @returns {Function} A new, debounced function.
   */


  function debounce(delay, atBegin, callback) {
    return callback === undefined ? throttle(delay, atBegin, false) : throttle(delay, callback, atBegin !== false);
  }

  exports.debounce = debounce;
  exports.throttle = throttle;
  Object.defineProperty(exports, '__esModule', {
    value: true
  });
});

/***/ }),
/* 7 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "setOptions", function() { return setOptions; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Set Custom Options

-------------------------------------------------------------------*/

function setOptions(newOpts) {
  var self = this;
  var optsTemplates = _utility__WEBPACK_IMPORTED_MODULE_0__["$"].extend({}, this.options.templates, newOpts && newOpts.templates || {});
  var optsShortcuts = _utility__WEBPACK_IMPORTED_MODULE_0__["$"].extend({}, this.options.shortcuts, newOpts && newOpts.shortcuts || {});
  self.options = _utility__WEBPACK_IMPORTED_MODULE_0__["$"].extend({}, self.options, newOpts);
  self.options.templates = optsTemplates;
  self.options.shortcuts = optsShortcuts;
}



/***/ }),
/* 8 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initCursor", function() { return initCursor; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

var START_POSITION = -100;
/*------------------------------------------------------------------

  Cursor

-------------------------------------------------------------------*/

function initCursor() {
  var self = this;

  if (!self.options.customCursor || _utility__WEBPACK_IMPORTED_MODULE_0__["isMobile"]) {
    return;
  }

  var clientX = START_POSITION;
  var clientY = START_POSITION;
  var xPos = START_POSITION;
  var yPos = START_POSITION;
  var dX = START_POSITION;
  var dY = START_POSITION;
  var lastRunTime = Date.now();
  var tickPos = 2;
  var fps = 1000 / 60;
  var $cursor = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('<div class="mpl-cursor"></div>');
  var $cursorOuter = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('<div class="mpl-cursor-outer"></div>');
  _utility__WEBPACK_IMPORTED_MODULE_0__["$body"].append([$cursor, $cursorOuter]).addClass('mpl-cursor-enabled');
  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('mousemove', function (e) {
    clientX = e.clientX;
    clientY = e.clientY;
  });
  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('mouseenter', 'a, button, input, textarea, [role="button"]', function () {
    $cursor.addClass('mpl-cursor-hover');
    $cursorOuter.addClass('mpl-cursor-hover');
  }).on('mouseleave', 'a, button, input, textarea, [role="button"]', function () {
    $cursor.removeClass('mpl-cursor-hover');
    $cursorOuter.removeClass('mpl-cursor-hover');
  }); // Move cursor.

  var moveCursor = function moveCursor() {
    var now = Date.now();
    var delay = now - lastRunTime;
    lastRunTime = now; // First run.

    if (xPos === START_POSITION) {
      dX = clientX;
      dY = clientY;
      xPos = clientX;
      yPos = clientY;
    } else {
      dX = clientX - xPos;
      dY = clientY - yPos;
      xPos += dX / (tickPos * fps / delay);
      yPos += dY / (tickPos * fps / delay);
    }

    $cursor.css('transform', "matrix(1, 0, 0, 1, ".concat(clientX, ", ").concat(clientY, ") translate3d(0,0,0)"));
    $cursorOuter.css('transform', "matrix(1, 0, 0, 1, ".concat(xPos, ", ").concat(yPos, ") translate3d(0,0,0)"));
    requestAnimationFrame(moveCursor);
  };

  requestAnimationFrame(moveCursor);
}



/***/ }),
/* 9 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initNavbar", function() { return initNavbar; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Navbar

-------------------------------------------------------------------*/

function initNavbar() {
  var self = this;
  var $navbarTop = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.mpl-navbar-top'); // navbar set to small

  Object(_utility__WEBPACK_IMPORTED_MODULE_0__["throttleScroll"])(function (type, scroll) {
    if (scroll > self.options.navbarSmallMaxTop && !self.options.navbarSmall) {
      self.options.navbarSmall = true;
      $navbarTop.addClass('mpl-navbar-small');
    }

    if (scroll <= self.options.navbarSmallMaxTop && self.options.navbarSmall) {
      self.options.navbarSmall = false;
      $navbarTop.removeClass('mpl-navbar-small');
    }
  }); // Mobile open

  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('click', '.mpl-navbar-top .mpl-navbar-toggle', function (e) {
    e.preventDefault();

    if (!_utility__WEBPACK_IMPORTED_MODULE_0__["$body"].hasClass('mpl-navbar-mobile-open')) {
      _utility__WEBPACK_IMPORTED_MODULE_0__["$body"].addClass('mpl-navbar-mobile-open');
      _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].trigger('mpl.navbar.mobile.show');
    }
  }); // Mobile close

  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('click', '.mpl-navbar-mobile-overlay, .mpl-navbar-mobile .mpl-navbar-toggle', function () {
    _utility__WEBPACK_IMPORTED_MODULE_0__["$body"].removeClass('mpl-navbar-mobile-open');
    _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].trigger('mpl.navbar.mobile.hide');
  }); // Correction of the scrollbar when opening the Modal

  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('show.bs.modal', function () {
    Object(_utility__WEBPACK_IMPORTED_MODULE_0__["bodyOverflow"])(1);
  });
  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('hidden.bs.modal', function () {
    Object(_utility__WEBPACK_IMPORTED_MODULE_0__["bodyOverflow"])(0);
  }); // Mobile collapse

  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('click', '.mpl-navbar-mobile .mpl-nav-link-collapse', function (e) {
    e.preventDefault();
    var $collapse = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this).next('.mpl-navbar-collapse');
    var isShowed = $collapse.hasClass('show');

    if (isShowed) {
      $collapse.removeClass('show').stop().css('display', 'block').slideUp(300, function () {
        $collapse.css('height', '');
        $collapse.find('.mpl-navbar-collapse.show').stop().removeClass('show');
      });
    } else {
      $collapse.addClass('show').stop().css('display', 'none').slideDown(300, function () {
        $collapse.css('height', '');
      });
    }
  }); // Dropdown

  var $dropdown = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.mpl-navbar-top .mpl-dropdown');
  var $dropdownMenu = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.mpl-navbar-top .mpl-dropdown-menu'); // closing the menu when click to the side

  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('mouseup', function (e) {
    var dropdownHas = $dropdown.has(e.target).length;

    if (!dropdownHas && $dropdown.hasClass('focus') || !dropdownHas && $dropdown.hasClass('show')) {
      $dropdown.removeClass('focus show').children('.mpl-dropdown-menu').removeClass('focus show');
    }
  }); // don't close the menu with the form

  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('focus', '.mpl-dropdown-menu:not(.show) input, .mpl-dropdown-menu:not(.show) textarea, .mpl-dropdown-menu:not(.show) button', function () {
    var $thisDropdown = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this).parents('.mpl-dropdown');
    $thisDropdown.addClass('show').children('.mpl-dropdown-menu').addClass('show');
  }); // closing the menu when hover to the other nav-link

  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('mouseenter', '.mpl-navbar-top .mpl-nav-link', function () {
    var $link = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this);
    var $dropdowns = $link.closest('.mpl-navbar-top').find('.mpl-dropdown.focus');

    if ($dropdowns.length) {
      $dropdowns.children('.mpl-nav-link').blur();
      $dropdowns.removeClass('focus').children('.mpl-dropdown-menu').removeClass('focus');
    }
  }); // show and hide the menu with focus

  function toggleShow() {
    var $thisDropdown = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this).parents('.mpl-dropdown');
    var $thisDropdownMenu = $thisDropdown.children('.mpl-dropdown-menu');

    if (!$thisDropdown.hasClass('focus')) {
      $thisDropdown.addClass('focus');
      $thisDropdownMenu.addClass('focus');
    } else {
      $thisDropdown.removeClass('focus');
      $thisDropdownMenu.removeClass('focus');
    }
  }

  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('focus', '.mpl-navbar-top a', toggleShow);
  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('blur', '.mpl-navbar-top a', toggleShow); // update position

  Object(_utility__WEBPACK_IMPORTED_MODULE_0__["debounceResize"])(function () {
    $dropdownMenu.each(function () {
      var $thisDropdownMenu = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this);
      var rect = $thisDropdownMenu[0].getBoundingClientRect();
      var rectLeft = parseInt(rect.left, 10);
      var rectRight = parseInt(_utility__WEBPACK_IMPORTED_MODULE_0__["wndW"] - rect.right, 10);
      var dropdownMarginLeft = parseInt($thisDropdownMenu.css('margin-left'), 10);
      var dropdownMarginRight = parseInt($thisDropdownMenu.css('margin-right'), 10);
      var css = {
        marginLeft: '',
        marginRight: ''
      };
      $thisDropdownMenu.css(css);

      if (rectRight < 0) {
        css.marginLeft = dropdownMarginLeft + rectRight;
      }

      if (rectLeft < 0) {
        css.marginRight = dropdownMarginRight + rectLeft;
      }

      $thisDropdownMenu.css(css);
    });
  }); // Hide when a key is pressed Esc

  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('keyup', function (e) {
    if (e.keyCode === 27) {
      // hide navbar mobile
      if (_utility__WEBPACK_IMPORTED_MODULE_0__["$body"].hasClass('mpl-navbar-mobile-open')) {
        _utility__WEBPACK_IMPORTED_MODULE_0__["$body"].removeClass('mpl-navbar-mobile-open');
      } // hide dropdown


      if ($dropdown.hasClass('focus show')) {
        $dropdown.removeClass('focus show').children('.mpl-dropdown-menu.focus').removeClass('focus show');
      }
    }
  });
}



/***/ }),
/* 10 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initAnchors", function() { return initAnchors; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Anchors

-------------------------------------------------------------------*/

function initAnchors() {
  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('click', 'a.btn, .mpl-navbar a', function (e) {
    var isHash = this.hash;
    var isURIsame = this.baseURI === window.location.href;

    if (isHash && isHash !== '#' && isHash !== '#!' && isURIsame) {
      var $hashBlock = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(isHash);
      var hash = isHash.replace(/^#/, '');

      if ($hashBlock.length) {
        // add hash to address bar
        $hashBlock.attr('id', '');
        document.location.hash = hash;
        $hashBlock.attr('id', hash); // scroll to block

        Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('html, body').stop().animate({
          scrollTop: $hashBlock.offset().top - 80
        }, 700);
        e.preventDefault();
      }
    }
  });
}



/***/ }),
/* 11 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initForms", function() { return initForms; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Init Forms

-------------------------------------------------------------------*/

function initForms() {
  var self = this; // ajax form submit

  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('submit', '.mpl-form-ajax', function (e) {
    e.preventDefault();
    var $form = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this);
    var $button = $form.find('[type="submit"]'); // if disabled button - stop this action

    if ($button.is('.disabled') || $button.is('[disabled]')) {
      return;
    }

    var $formResponse = $form.next('.mpl-form-response');

    if (!$formResponse.length) {
      $formResponse = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('<div class="mpl-form-response mt-30"></div>');
      $formResponse.insertAfter($form);
    }

    _utility__WEBPACK_IMPORTED_MODULE_0__["$"].ajax({
      type: 'POST',
      url: $form.attr('action'),
      data: $form.serialize(),
      success: function success(response) {
        response = JSON.parse(response);

        if (response.type && response.type === 'success') {
          $formResponse.html("<div class=\"alert alert-success\">".concat(response.response, "</div>"));
          $form[0].reset();
        } else {
          $formResponse.html("<div class=\"alert alert-error\">".concat(response.response, "</div>"));
        }

        self.debounceResize();
      },
      error: function error(response) {
        $formResponse.html("<div class=\"alert alert-error\">".concat(response.responseText, "</div>"));
        self.debounceResize();
      }
    });
  });
}



/***/ }),
/* 12 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initHexagonRating", function() { return initHexagonRating; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Init Hexagon Rating

-------------------------------------------------------------------*/

function initHexagonRating() {
  Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.mpl-hexagon-rating').each(function () {
    var $this = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this);
    var percent = parseInt($this.attr('data-hexagon'), 10);
    var max = 2220; // eslint-disable-next-line

    var pathD = 'M748.305 412.622L589.475 689.622C580.652 705.01 564.271 714.5 546.533 714.5H229.467C211.729 714.5 195.348 705.01 186.525 689.622L27.6948 412.622C18.9503 397.372 18.9503 378.628 27.6948 363.377L186.525 86.3775C195.348 70.9903 211.729 61.5 229.467 61.5H546.533C564.271 61.5 580.652 70.9903 589.475 86.3775L748.305 363.378C757.05 378.628 757.05 397.372 748.305 412.622Z';
    $this.append("<svg class=\"mpl-hexagon\" viewBox=\"0 0 776 776\" xmlns=\"http://www.w3.org/2000/svg\">\n                <path class=\"mpl-hexagon-track\" d=\"".concat(pathD, "\"/>\n                <path class=\"mpl-hexagon-fill\" d=\"").concat(pathD, "\"/>\n                <path class=\"mpl-hexagon-fix\" d=\"M748.739 412.871L747.871 412.374C751.856 405.424 754.007 397.741 754.323 390H755.324C755.007 397.913 752.812 405.767 748.739 412.871Z\"/>\n            </svg>"));
    var $hexagon = $this.children('svg');
    $hexagon.children('.mpl-hexagon-fill').css('stroke-dashoffset', "".concat((100 - percent) / 100 * max));
  });
}



/***/ }),
/* 13 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initTwitter", function() { return initTwitter; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Twitter
  https://github.com/sonnyt/Tweetie

-------------------------------------------------------------------*/

function initTwitter() {
  var self = this;
  var $twtFeeds = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.mpl-twitter');

  if (!$twtFeeds.length || !self.options.templates.twitter) {
    return;
  }
  /**
   * Templating a tweet using '{{ }}' braces
   * @param  {Object} data Tweet details are passed
   * @return {String}      Templated string
   */


  function templating(data, temp) {
    var tempVariables = ['date', 'tweet', 'avatar', 'url', 'retweeted', 'screen_name', 'user_name'];

    for (var i = 0, len = tempVariables.length; i < len; i++) {
      temp = temp.replace(new RegExp("{{".concat(tempVariables[i], "}}"), 'gi'), data[tempVariables[i]]);
    }

    return temp;
  }

  $twtFeeds.each(function () {
    var $this = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this);
    var options = {
      username: $this.attr('data-twitter-user-name') || null,
      list: null,
      hashtag: $this.attr('data-twitter-hashtag') || null,
      count: $this.attr('data-twitter-count') || 2,
      hideReplies: $this.attr('data-twitter-hide-replies') === 'true',
      template: $this.attr('data-twitter-template') || self.options.templates.twitter,
      loadingText: self.options.templates.twitterLoadingText,
      failText: self.options.templates.twitterFailText,
      apiPath: self.options.php.twitter
    }; // stop if running in file protocol

    if (window.location.protocol === 'file:') {
      $this.html(options.failText); // eslint-disable-next-line

      console.error('You should run you website on webserver with PHP to get working Twitter');
      return;
    } // Set loading


    $this.html("<span>".concat(options.loadingText, "</span>")); // Fetch tweets

    _utility__WEBPACK_IMPORTED_MODULE_0__["$"].getJSON(options.apiPath, {
      username: options.username,
      list: options.list,
      hashtag: options.hashtag,
      count: options.count,
      exclude_replies: options.hideReplies
    }, function (twt) {
      $this.html('');

      for (var i = 0; i < options.count; i++) {
        var tweet = false;

        if (twt[i]) {
          tweet = twt[i];
        } else if (twt.statuses && twt.statuses[i]) {
          tweet = twt.statuses[i];
        } else {
          break;
        }

        var tempData = {
          user_name: tweet.user.name,
          date: tweet.date_formatted,
          tweet: tweet.text_entitled,
          avatar: "<img src=\"".concat(tweet.user.profile_image_url_https, "\" />"),
          url: "https://twitter.com/".concat(tweet.user.screen_name, "/status/").concat(tweet.id_str),
          retweeted: tweet.retweeted,
          screen_name: "@".concat(tweet.user.screen_name)
        };
        $this.append(templating(tempData, options.template));
      } // resize window


      self.debounceResize();
    }).fail(function (a) {
      $this.html(options.failText);
      _utility__WEBPACK_IMPORTED_MODULE_0__["$"].error(a.responseText);
    });
  });
}



/***/ }),
/* 14 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initFacebook", function() { return initFacebook; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Init Facebook

-------------------------------------------------------------------*/

function initFacebook() {
  if (!Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.fb-page').length) {
    return;
  }

  var self = this;
  _utility__WEBPACK_IMPORTED_MODULE_0__["$body"].append('<div id="fb-root"></div>');

  (function (d, s, id) {
    if (window.location.protocol === 'file:') {
      return;
    }

    var fjs = d.getElementsByTagName(s)[0];

    if (d.getElementById(id)) {
      return;
    }

    var js = d.createElement(s);
    js.id = id;
    js.src = '//connect.facebook.net/en_US/sdk.js#xfbml=1&version=v2.4';
    fjs.parentNode.insertBefore(js, fjs);
  })(document, 'script', 'facebook-jssdk'); // resize on facebook widget loaded


  window.fbAsyncInit = function () {
    window.FB.Event.subscribe('xfbml.render', function () {
      // resize window
      self.debounceResize();
    });
  };
}



/***/ }),
/* 15 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initInstagram", function() { return initInstagram; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Init Instagram

-------------------------------------------------------------------*/

function initInstagram() {
  var self = this;
  var $instagram = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.mpl-instagram');

  if (!$instagram.length || !self.options.templates.instagram) {
    return;
  }
  /**
   * Templating a instagram item using '{{ }}' braces
   * @param  {Object} data Instagram item details are passed
   * @return {String} Templated string
   */


  function templating(data, temp) {
    var tempVariables = ['link', 'image', 'caption'];

    for (var i = 0, len = tempVariables.length; i < len; i++) {
      temp = temp.replace(new RegExp("{{".concat(tempVariables[i], "}}"), 'gi'), data[tempVariables[i]]);
    }

    return temp;
  }

  $instagram.each(function () {
    var $this = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this);
    var options = {
      columnClass: $this.attr('data-instagram-column-class'),
      userName: $this.attr('data-instagram-user-name') || null,
      count: $this.attr('data-instagram-count') || 8,
      template: $this.attr('data-instagram-template') || self.options.templates.instagram,
      quality: $this.attr('data-instagram-quality') || 'sm',
      // sm, md, lg
      loadingText: self.options.templates.instagramLoadingText,
      failText: self.options.templates.instagramFailText,
      apiPath: self.options.php.instagram
    }; // stop if running in file protocol

    if (window.location.protocol === 'file:') {
      $this.html("<div class=\"col-12\">".concat(options.failText, "</div>")); // eslint-disable-next-line

      console.error('You should run you website on webserver with PHP to get working Instagram');
      return;
    }

    $this.html("<div class=\"col-12\">".concat(options.loadingText, "</div>")); // Fetch instagram images

    _utility__WEBPACK_IMPORTED_MODULE_0__["$"].getJSON(options.apiPath, {
      userName: options.userName,
      count: options.count
    }, function (response) {
      $this.html('');

      if (response) {
        for (var i = 0; i < options.count; i++) {
          var instaItem = false;

          if (response[i]) {
            instaItem = response[i];
          } else if (response.statuses && response.statuses[i]) {
            instaItem = response.statuses[i];
          } else {
            break;
          }

          var resolution = 'thumbnail';

          if (options.quality === 'md') {
            resolution = 'low_resolution';
          }

          if (options.quality === 'lg') {
            resolution = 'standard_resolution';
          }

          var tempData = {
            link: instaItem.link,
            image: instaItem.images[resolution].url,
            caption: instaItem.caption
          };
          $this.append(templating(tempData, options.template));
        }
      } // resize window


      self.debounceResize(); // create columns

      if (options.columnClass) {
        $this.children().wrap("<div class=\"".concat(options.columnClass, "\"></div>"));
      }
    }).fail(function (a) {
      $this.html("<div class=\"col-12\">".concat(options.failText, "</div>"));
      _utility__WEBPACK_IMPORTED_MODULE_0__["$"].error(a.responseText);
    });
  });
}



/***/ }),
/* 16 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initPluginScrollReveal", function() { return initPluginScrollReveal; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);


function maybeRun() {
  Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('[data-sr]').each(function () {
    var $this = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this);
    var dataId = $this.attr('data-sr') || '';
    var dataInterval = parseInt($this.attr('data-sr-interval'), 10);
    var dataDuration = parseInt($this.attr('data-sr-duration'), 10);
    var dataDelay = parseInt($this.attr('data-sr-delay'), 10);
    var dataScale = parseFloat($this.attr('data-sr-scale'));
    var dataOrigin = $this.attr('data-sr-origin');
    var dataDistance = $this.attr('data-sr-distance');
    var conf = {};
    var $item = $this.find("[data-sr-item=\"".concat(dataId, "\"]"));
    conf.reset = true;
    conf.cleanup = true;

    if (!$item.length) {
      $item = $this;
    } // Animated shop and blog posts


    var $shopOrPost = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.mpl-shop, .mpl-post');

    if ($shopOrPost.length) {
      conf.reset = false;
      conf.duration = 1400;
      window.ScrollReveal().reveal($shopOrPost, conf);
    }

    conf.reset = false;

    if (dataInterval) {
      conf.interval = dataInterval;
    }

    if (dataDuration) {
      conf.duration = dataDuration;
    }

    if (dataDelay) {
      conf.delay = dataDelay;
    }

    if (dataScale) {
      conf.scale = dataScale;
    }

    if (dataOrigin) {
      conf.origin = dataOrigin;
    }

    if (dataDistance) {
      conf.distance = "".concat(dataDistance, "px");
    }

    window.ScrollReveal().reveal($item, conf);
  });
  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('arrangeComplete', '.mpl-isotope-grid', function () {
    window.ScrollReveal().delegate({
      type: 'resize'
    });
  });
}

function initPluginScrollReveal() {
  if (typeof ScrollReveal === 'undefined') {
    return;
  }

  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('mpl.preloader.hide', function () {
    setTimeout(function () {
      maybeRun();
    }, 400);
  });
}



/***/ }),
/* 17 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initPluginAnime", function() { return initPluginAnime; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Init Plugin Animejs

-------------------------------------------------------------------*/

function initPluginAnime() {
  var _window = window,
      anime = _window.anime;

  if (typeof anime === 'undefined') {
    return;
  } // navbar


  var navbar = anime({
    opacity: [0, 1],
    easing: 'easeOutSine',
    duration: 400,
    targets: '.mpl-navbar-top .mpl-navbar-content > .mpl-navbar-nav > li',
    translateY: [-10, 0],
    autoplay: false,
    delay: anime.stagger(80, {
      start: 100
    })
  }); // navbar mobile body

  var navbarMobileBody = anime({
    opacity: [0, 1],
    easing: 'easeOutSine',
    duration: 400,
    targets: '.mpl-navbar-mobile .mpl-navbar-body > .mpl-navbar-nav > li',
    translateX: [20, 0],
    autoplay: false,
    delay: anime.stagger(80, {
      start: 200
    })
  }); // navbar mobile footer

  var navbarMobileFooter = anime({
    opacity: [0, 1],
    easing: 'easeOutSine',
    duration: 400,
    targets: '.mpl-navbar-mobile .mpl-navbar-footer > .mpl-navbar-nav > li',
    translateY: [20, 0],
    autoplay: false,
    delay: anime.stagger(80, {
      start: 600
    })
  });
  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('mpl.preloader.hide', function () {
    setTimeout(function () {
      navbar.play();
    }, 100);
  });
  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('mpl.navbar.mobile.show', function () {
    navbarMobileBody.play();
    navbarMobileFooter.play();
  }); // navbar open collapse

  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('show.bs.collapse', function (e) {
    anime({
      opacity: [0, 1],
      easing: 'easeOutSine',
      duration: 200,
      targets: e.target.querySelectorAll('li'),
      translateX: [10, 0],
      autoplay: false,
      delay: anime.stagger(80, {
        start: 100
      })
    }).play();
  });
}



/***/ }),
/* 18 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initPluginObjectFitImages", function() { return initPluginObjectFitImages; });
/*------------------------------------------------------------------

  Object Fit Images

-------------------------------------------------------------------*/
function initPluginObjectFitImages() {
  if (typeof objectFitImages !== 'undefined') {
    objectFitImages();
  }
}



/***/ }),
/* 19 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initPluginCountUp", function() { return initPluginCountUp; });
/* harmony import */ var countup_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(20);
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(5);


/*------------------------------------------------------------------

  Init CountUp

-------------------------------------------------------------------*/

function initPluginCountUp() {
  if (typeof countup_js__WEBPACK_IMPORTED_MODULE_0__["CountUp"] === 'undefined') {
    return;
  }

  Object(_utility__WEBPACK_IMPORTED_MODULE_1__["throttleScroll"])(function () {
    Object(_utility__WEBPACK_IMPORTED_MODULE_1__["$"])('.mpl-count:not(.mpl-count-stop)').each(function () {
      var $this = Object(_utility__WEBPACK_IMPORTED_MODULE_1__["$"])(this);
      var number = parseInt($this.text(), 10);
      var dataDuration = parseInt($this.attr('data-count-duration'), 10);
      var conf = {};

      if (Object(_utility__WEBPACK_IMPORTED_MODULE_1__["isInViewport"])($this) > 0) {
        conf.useGrouping = false;

        if (dataDuration) {
          conf.duration = dataDuration;
        } else {
          conf.duration = 3;
        }

        var countUp = new countup_js__WEBPACK_IMPORTED_MODULE_0__["CountUp"]($this[0], number, conf);
        countUp.start();
        $this.addClass('mpl-count-stop');
      }
    });
  });
}



/***/ }),
/* 20 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "CountUp", function() { return CountUp; });
var __assign = undefined && undefined.__assign || function () {
  return (__assign = Object.assign || function (t) {
    for (var i, a = 1, s = arguments.length; a < s; a++) {
      for (var n in i = arguments[a]) {
        Object.prototype.hasOwnProperty.call(i, n) && (t[n] = i[n]);
      }
    }

    return t;
  }).apply(this, arguments);
},
    CountUp = function () {
  function t(t, i, a) {
    var s = this;
    this.target = t, this.endVal = i, this.options = a, this.version = "2.0.7", this.defaults = {
      startVal: 0,
      decimalPlaces: 0,
      duration: 2,
      useEasing: !0,
      useGrouping: !0,
      smartEasingThreshold: 999,
      smartEasingAmount: 333,
      separator: ",",
      decimal: ".",
      prefix: "",
      suffix: ""
    }, this.finalEndVal = null, this.useEasing = !0, this.countDown = !1, this.error = "", this.startVal = 0, this.paused = !0, this.count = function (t) {
      s.startTime || (s.startTime = t);
      var i = t - s.startTime;
      s.remaining = s.duration - i, s.useEasing ? s.countDown ? s.frameVal = s.startVal - s.easingFn(i, 0, s.startVal - s.endVal, s.duration) : s.frameVal = s.easingFn(i, s.startVal, s.endVal - s.startVal, s.duration) : s.countDown ? s.frameVal = s.startVal - (s.startVal - s.endVal) * (i / s.duration) : s.frameVal = s.startVal + (s.endVal - s.startVal) * (i / s.duration), s.countDown ? s.frameVal = s.frameVal < s.endVal ? s.endVal : s.frameVal : s.frameVal = s.frameVal > s.endVal ? s.endVal : s.frameVal, s.frameVal = Number(s.frameVal.toFixed(s.options.decimalPlaces)), s.printValue(s.frameVal), i < s.duration ? s.rAF = requestAnimationFrame(s.count) : null !== s.finalEndVal ? s.update(s.finalEndVal) : s.callback && s.callback();
    }, this.formatNumber = function (t) {
      var i,
          a,
          n,
          e,
          r,
          o = t < 0 ? "-" : "";

      if (i = Math.abs(t).toFixed(s.options.decimalPlaces), n = (a = (i += "").split("."))[0], e = a.length > 1 ? s.options.decimal + a[1] : "", s.options.useGrouping) {
        r = "";

        for (var l = 0, h = n.length; l < h; ++l) {
          0 !== l && l % 3 == 0 && (r = s.options.separator + r), r = n[h - l - 1] + r;
        }

        n = r;
      }

      return s.options.numerals && s.options.numerals.length && (n = n.replace(/[0-9]/g, function (t) {
        return s.options.numerals[+t];
      }), e = e.replace(/[0-9]/g, function (t) {
        return s.options.numerals[+t];
      })), o + s.options.prefix + n + e + s.options.suffix;
    }, this.easeOutExpo = function (t, i, a, s) {
      return a * (1 - Math.pow(2, -10 * t / s)) * 1024 / 1023 + i;
    }, this.options = __assign(__assign({}, this.defaults), a), this.formattingFn = this.options.formattingFn ? this.options.formattingFn : this.formatNumber, this.easingFn = this.options.easingFn ? this.options.easingFn : this.easeOutExpo, this.startVal = this.validateValue(this.options.startVal), this.frameVal = this.startVal, this.endVal = this.validateValue(i), this.options.decimalPlaces = Math.max(this.options.decimalPlaces), this.resetDuration(), this.options.separator = String(this.options.separator), this.useEasing = this.options.useEasing, "" === this.options.separator && (this.options.useGrouping = !1), this.el = "string" == typeof t ? document.getElementById(t) : t, this.el ? this.printValue(this.startVal) : this.error = "[CountUp] target is null or undefined";
  }

  return t.prototype.determineDirectionAndSmartEasing = function () {
    var t = this.finalEndVal ? this.finalEndVal : this.endVal;
    this.countDown = this.startVal > t;
    var i = t - this.startVal;

    if (Math.abs(i) > this.options.smartEasingThreshold) {
      this.finalEndVal = t;
      var a = this.countDown ? 1 : -1;
      this.endVal = t + a * this.options.smartEasingAmount, this.duration = this.duration / 2;
    } else this.endVal = t, this.finalEndVal = null;

    this.finalEndVal ? this.useEasing = !1 : this.useEasing = this.options.useEasing;
  }, t.prototype.start = function (t) {
    this.error || (this.callback = t, this.duration > 0 ? (this.determineDirectionAndSmartEasing(), this.paused = !1, this.rAF = requestAnimationFrame(this.count)) : this.printValue(this.endVal));
  }, t.prototype.pauseResume = function () {
    this.paused ? (this.startTime = null, this.duration = this.remaining, this.startVal = this.frameVal, this.determineDirectionAndSmartEasing(), this.rAF = requestAnimationFrame(this.count)) : cancelAnimationFrame(this.rAF), this.paused = !this.paused;
  }, t.prototype.reset = function () {
    cancelAnimationFrame(this.rAF), this.paused = !0, this.resetDuration(), this.startVal = this.validateValue(this.options.startVal), this.frameVal = this.startVal, this.printValue(this.startVal);
  }, t.prototype.update = function (t) {
    cancelAnimationFrame(this.rAF), this.startTime = null, this.endVal = this.validateValue(t), this.endVal !== this.frameVal && (this.startVal = this.frameVal, this.finalEndVal || this.resetDuration(), this.finalEndVal = null, this.determineDirectionAndSmartEasing(), this.rAF = requestAnimationFrame(this.count));
  }, t.prototype.printValue = function (t) {
    var i = this.formattingFn(t);
    "INPUT" === this.el.tagName ? this.el.value = i : "text" === this.el.tagName || "tspan" === this.el.tagName ? this.el.textContent = i : this.el.innerHTML = i;
  }, t.prototype.ensureNumber = function (t) {
    return "number" == typeof t && !isNaN(t);
  }, t.prototype.validateValue = function (t) {
    var i = Number(t);
    return this.ensureNumber(i) ? i : (this.error = "[CountUp] invalid start or end value: " + t, null);
  }, t.prototype.resetDuration = function () {
    this.startTime = null, this.duration = 1e3 * Number(this.options.duration), this.remaining = this.duration;
  }, t;
}();



/***/ }),
/* 21 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initPluginSwiper", function() { return initPluginSwiper; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Init Plugin Swiper

-------------------------------------------------------------------*/

function initPluginSwiper() {
  if (typeof Swiper === 'undefined') {
    return;
  }

  Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.mpl-carousel').each(function () {
    var $this = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this);
    var dataLoop = $this.attr('data-loop');
    var dataButtons = $this.attr('data-arrows');
    var dataPagination = $this.attr('data-dots');
    var dataGrabCursor = $this.attr('data-grabCursor');
    var dataAutoHeight = $this.attr('data-autoHeight');
    var dataBreakpoints = $this.attr('data-breakpoints');
    var dataScrollbar = $this.attr('data-scrollbar');
    var dataSlides = $this.attr('data-slides');
    var dataAutoplay = parseInt($this.attr('data-autoplay'), 10);
    var dataSpeed = parseInt($this.attr('data-speed'), 10);
    var dataGap = parseInt($this.attr('data-gap'), 10);
    var conf = {
      // fixes the conflict with custom cursor movement.
      touchStartPreventDefault: false
    }; // creating slides

    if ($this.find('.swiper-slide').length === 0) {
      $this.children().wrap('<div class="swiper-slide"></div>');
    } // creating wrapper


    if ($this.find('.swiper-wrapper').length === 0) {
      $this.children().wrapAll('<div class="swiper-wrapper"></div>');
    } // creating container


    if ($this.find('.swiper-container').length === 0) {
      $this.children().wrap('<div class="swiper-container"></div>');
    } // creating buttons


    if (dataButtons) {
      $this.append('<div class="swiper-button-prev"></div><div class="swiper-button-next"></div>');
    } // creating pagination


    if (dataPagination) {
      $this.append('<div class="swiper-pagination"></div>');
    }

    var $container = $this.find('.swiper-container');
    var $btnPrev = $this.children('.swiper-button-prev');
    var $btnNext = $this.children('.swiper-button-next'); // custom arrow

    if (dataButtons) {
      $btnPrev.append('<svg width="5" height="10" viewBox="0 0 5 10" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M4 9L1 5L4 1" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>');
      $btnNext.append('<svg width="5" height="10" viewBox="0 0 5 10" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M1 9L4 5L1 1" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>');
    }

    if ($btnPrev.length && $btnNext.length) {
      conf.navigation = {
        nextEl: $btnNext[0],
        prevEl: $btnPrev[0]
      };
    }

    if (dataLoop) {
      conf.loop = true;
    }

    if (dataGrabCursor) {
      conf.grabCursor = true;
    }

    if (dataAutoHeight) {
      conf.autoHeight = true;
    }

    if (dataScrollbar) {
      $container.append('<div class="swiper-scrollbar"></div>');
      conf.scrollbar = {
        el: $container.children('.swiper-scrollbar'),
        hide: false,
        draggable: true
      };
    }

    if (dataAutoplay) {
      conf.autoplay = {
        delay: dataAutoplay
      };
    }

    if (dataSpeed) {
      conf.speed = dataSpeed;
    }

    if (dataSlides === 'auto') {
      conf.slidesPerView = 'auto';
    } else {
      conf.slidesPerView = parseInt(dataSlides, 10);
    }

    if (dataGap) {
      conf.spaceBetween = dataGap;
    }

    if (dataBreakpoints) {
      var i = 0;
      var breaks = {};
      var points = dataBreakpoints.split(',');

      while (i < dataBreakpoints.split(',').length) {
        breaks[parseInt(points[i].split(':')[0], 10)] = {
          slidesPerView: parseInt(points[i].split(':')[1], 10)
        };
        i++;
      }

      conf.breakpoints = breaks;
    } // eslint-disable-next-line


    new Swiper($container[0], conf);
  });
}



/***/ }),
/* 22 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initPluginSliderRevolution", function() { return initPluginSliderRevolution; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Slider Revolution

-------------------------------------------------------------------*/

function initPluginSliderRevolution() {
  if (typeof _utility__WEBPACK_IMPORTED_MODULE_0__["$"].fn.revolution === 'undefined') {
    return;
  }

  Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.mpl-rs').each(function () {
    var $item = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this); // options

    var rsOptions = {
      dottedOverlay: 'none',
      navigationType: 'bullet',
      navigationArrows: 'solo',
      navigationStyle: 'preview4',
      spinner: 'spinner4',
      sliderType: 'standard',
      sliderLayout: $item.hasClass('rs-fullscreen') ? 'fullscreen' : 'auto',
      delay: 9000,
      navigation: {
        keyboardNavigation: 'off',
        keyboard_direction: 'horizontal',
        mouseScrollNavigation: 'off',
        mouseScrollReverse: 'default',
        onHoverStop: 'off',
        touch: {
          touchenabled: 'on',
          swipe_threshold: 75,
          swipe_min_touches: 1,
          swipe_direction: 'horizontal',
          drag_block_vertical: false
        },
        arrows: {
          enable: true,
          style: 'hermes',
          tmp: '<div class="tp-arr-allwrapper"><div class="tp-arr-imgholder"></div></div>'
        },
        bullets: {
          enable: true,
          style: 'hebe',
          tmp: '<span class="tp-bullet-image"></span>',
          hide_onmobile: true,
          hide_under: 600,
          hide_onleave: true,
          hide_delay: 200,
          hide_delay_mobile: 1200,
          direction: 'horizontal',
          h_align: 'center',
          v_align: 'bottom',
          h_offset: 0,
          v_offset: 30,
          space: 5
        }
      },
      viewPort: {
        enable: true,
        outof: 'pause',
        visible_area: '80%',
        presize: false
      },
      responsiveLevels: [1240, 1024, 778, 480],
      visibilityLevels: [1240, 1024, 778, 480],
      gridwidth: [1240, 1024, 778, 480],
      gridheight: [600, 600, 500, 400],
      lazyType: 'smart',
      parallax: {
        type: 'mouse',
        origo: 'slidercenter',
        speed: 2000,
        levels: [2, 3, 4, 5, 6, 7, 12, 16, 10, 50, 46, 47, 48, 49, 50, 55]
      },
      shadow: 0,
      stopLoop: 'off',
      stopAfterLoops: -1,
      stopAtSlide: -1,
      shuffle: 'off',
      autoHeight: 'off',
      hideThumbsOnMobile: 'off',
      hideSliderAtLimit: 0,
      hideCaptionAtLimit: 0,
      hideAllCaptionAtLilmit: 0,
      debugMode: false,
      fallbacks: {
        simplifyAll: 'off',
        nextSlideOnWindowFocus: 'off',
        disableFocusListener: false
      }
    }; // init

    $item.find('.tp-banner, .rev_slider').show().revolution(rsOptions);
  });
}



/***/ }),
/* 23 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initPluginIsotope", function() { return initPluginIsotope; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Isotope

-------------------------------------------------------------------*/

function initPluginIsotope() {
  if (typeof _utility__WEBPACK_IMPORTED_MODULE_0__["$"].fn.isotope === 'undefined') {
    return;
  }

  Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.mpl-isotope').each(function () {
    var $this = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this);
    var curIsotopeOptions = $this.find('.mpl-isotope-options'); // init items

    var $grid = $this.find('.mpl-isotope-grid').isotope({
      itemSelector: '.mpl-isotope-item'
    }); // refresh for parallax images and isotope images position

    if ($grid.imagesLoaded) {
      $grid.imagesLoaded().progress(function () {
        $grid.isotope('layout');
      });
    } // click on filter button


    curIsotopeOptions.on('click', '> :not(.active)', function (e) {
      Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this).addClass('active').siblings().removeClass('active');
      var curFilter = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this).attr('data-filter');
      e.preventDefault();
      $grid.isotope({
        filter: function filter() {
          if (curFilter === 'all') {
            return true;
          }

          var itemFilters = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this).attr('data-filters');

          if (itemFilters) {
            itemFilters = itemFilters.split(','); // eslint-disable-next-line

            for (var k in itemFilters) {
              if (itemFilters[k].replace(/\s/g, '') === curFilter) {
                return true;
              }
            }
          }

          return false;
        }
      });
    });
  });
}



/***/ }),
/* 24 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initPluginTouchSpin", function() { return initPluginTouchSpin; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Init Plugin TouchSpin

-------------------------------------------------------------------*/

function initPluginTouchSpin() {
  if (typeof _utility__WEBPACK_IMPORTED_MODULE_0__["$"].fn.TouchSpin === 'undefined') {
    return;
  }

  Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.mpl-touchspin').each(function () {
    var $input = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this);
    var dataMin = $input.attr('min');
    var dataMax = $input.attr('max');
    var conf = {};
    conf.boostat = 5;
    conf.maxboostedstep = 10;
    conf.step = 1;
    conf.forcestepdivisibility = 'none';
    conf.buttonup_class = 'btn';
    conf.buttondown_class = 'btn';
    conf.verticalbuttons = true;

    if (dataMin) {
      conf.min = dataMin;
    }

    if (dataMax) {
      conf.max = dataMax;
    }

    $input.TouchSpin(conf);
    $input.after('<div class="form-control-bg"></div>');
  });
}



/***/ }),
/* 25 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initPluginFancybox", function() { return initPluginFancybox; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Init Plugin Fancybox

-------------------------------------------------------------------*/

function initPluginFancybox() {
  if (typeof _utility__WEBPACK_IMPORTED_MODULE_0__["$"].fn.fancybox === 'undefined') {
    return;
  }

  _utility__WEBPACK_IMPORTED_MODULE_0__["$"].fancybox.defaults.backFocus = false; // Close Escape

  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('keyup', function (e) {
    if (e.keyCode === 27) {
      _utility__WEBPACK_IMPORTED_MODULE_0__["$"].fancybox.close();
    }
  });
  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('beforeShow.fb', function () {
    Object(_utility__WEBPACK_IMPORTED_MODULE_0__["bodyOverflow"])(1);
  });
  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('beforeClose.fb', function () {
    _utility__WEBPACK_IMPORTED_MODULE_0__["$body"].addClass('fancybox-active-closing');
  });
  _utility__WEBPACK_IMPORTED_MODULE_0__["$doc"].on('afterClose.fb', function () {
    Object(_utility__WEBPACK_IMPORTED_MODULE_0__["bodyOverflow"])(0);
    _utility__WEBPACK_IMPORTED_MODULE_0__["$body"].removeClass('fancybox-active-closing');
  });
}



/***/ }),
/* 26 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initPluginRangeslider", function() { return initPluginRangeslider; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Rangeslider

-------------------------------------------------------------------*/

function initPluginRangeslider() {
  if (typeof _utility__WEBPACK_IMPORTED_MODULE_0__["$"].fn.ionRangeSlider === 'undefined') {
    return;
  }

  Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.mpl-rangeslider').ionRangeSlider();
}



/***/ }),
/* 27 */
/***/ (function(module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export (binding) */ __webpack_require__.d(__webpack_exports__, "initPluginJarallax", function() { return initPluginJarallax; });
/* harmony import */ var _utility__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(5);

/*------------------------------------------------------------------

  Jarallax

-------------------------------------------------------------------*/

function initPluginJarallax() {
  if (!this.options.parallax || _utility__WEBPACK_IMPORTED_MODULE_0__["isMobile"]) {
    return;
  } // in newest versions used Jarallax plugin


  if (typeof _utility__WEBPACK_IMPORTED_MODULE_0__["$"].fn.jarallax === 'undefined') {
    return;
  } // banners


  Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.mpl-banner-parallax .mpl-image').each(function () {
    var speed = parseFloat(Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this).attr('data-speed'));
    var $banner = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this).closest('.mpl-banner-parallax');
    var $info = $banner.children('.mpl-banner-content');
    var isTopBanner = $banner.hasClass('mpl-banner-top');
    Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this).jarallax({
      automaticResize: true,
      speed: Number.isNaN(speed) ? 0.4 : speed,
      onScroll: function onScroll(calc) {
        if (!isTopBanner) {
          return;
        }

        $info.css({
          filter: "blur(".concat(parseInt(calc.afterTop, 10) / 250, "px)")
        });
      }
    });
  }); // footer parallax

  Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])('.mpl-footer-parallax').each(function () {
    var $this = Object(_utility__WEBPACK_IMPORTED_MODULE_0__["$"])(this);
    var $img = $this.children('.mpl-image');
    var $wrapper = $this.children('.mpl-footer-wrapper');
    var opts = {
      automaticResize: true,
      onScroll: function onScroll(calc) {
        $wrapper.css({
          filter: "blur(".concat(parseInt(calc.beforeBottom, 10) / 200, "px)")
        });
      }
    };

    if (!$img.length) {
      opts.type = 'custom';
      opts.imgSrc = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
      opts.imgWidth = 1;
      opts.imgHeight = 1;
      $this.jarallax(opts);
    } else {
      $img.jarallax(opts);
    }
  });
}



/***/ })
/******/ ]);