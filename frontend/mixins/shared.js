import Vue from 'vue'
import moment from 'moment'
import store from '../store.js'
import api from '../api/api'
import { Base64 } from 'js-base64'
import _ from 'lodash'

import english from '../translations/english'
import german from '../translations/german'

const funcs = {
  methods: {

    /**
     * example:
     *      lang("{0} is dead, but {1} is alive! {0} {2}", "HTML", "HTML5")
     * output:
     *      HTML is dead, but HTML5 is alive! HTML {2}
     **/
    lang(term, ...rest) {

      let available_languages = {
        'english': english,
        'german': german,
      }

      let language = store.state.config.language

      let args = rest
      if(!available_languages[language] || available_languages[language][term] == undefined) {
        // translation required
        return term
      }
      return available_languages[language][term].replace(/{(\d+)}/g, function(match, number) {
        return typeof args[number] != 'undefined'
          ? args[number]
          : match
      })
    },
    is(role) {
      return this.$store.state.user.role == role
    },
    can(permissions) {
      return this.$store.getters.hasPermissions(permissions)
    },
    formatBytes(bytes, decimals = 2) {
      if (bytes === 0) return '0 Bytes'

      const k = 1024
      const dm = decimals < 0 ? 0 : decimals
      const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']

      const i = Math.floor(Math.log(bytes) / Math.log(k))

      return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i]
    },
    formatDate(timestamp) {
      return moment.unix(timestamp).format(store.state.config.date_format ? store.state.config.date_format : 'YY/MM/DD hh:mm:ss')
    },
    checkUser() {
      api.getUser()
        .then((user) => {
          if (user.username !== store.state.user.username) {
            this.$store.commit('destroyUser', user)
            this.$toast.open({
              message: this.lang('Please log in'),
              type: 'is-danger',
            })
          }
        })
        .catch(() => {
          this.$toast.open({
            message: this.lang('Please log in'),
            type: 'is-danger',
          })
        })
    },
    handleError(error) {
      this.checkUser()

      if (typeof error == 'string') {
        this.$toast.open({
          message: this.lang(error),
          type: 'is-danger',
          duration: 5000,
        })
        return
      } else if (error && error.response && error.response.data && error.response.data.data) {
        this.$toast.open({
          message: this.lang(error.response.data.data),
          type: 'is-danger',
          duration: 5000,
        })
        return
      }

      this.$toast.open({
        message: this.lang('Unknown error'),
        type: 'is-danger',
        duration: 5000,
      })
    },
    getDownloadLink(path) {
      return Vue.config.baseURL+'/download&path='+encodeURIComponent(Base64.encode(path))
    },
    getPublicLink(path) {
      const configuredBaseUrl = store.state.config.public_base_url || '/files'
      const baseUrl = new URL(configuredBaseUrl, window.location.origin)
        .toString()
        .replace(/\/+$/, '')
      const encodedPath = path
        .split('/')
        .filter(segment => segment.length > 0)
        .map(segment => encodeURIComponent(segment))
        .join('/')

      return encodedPath ? baseUrl+'/'+encodedPath : baseUrl
    },
    isPublicFile(name) {
      return this.hasExtension(name, store.state.config.public_file_extensions || [])
    },
    hasPreview(name) {
      return this.isImage(name)
    },
    isImage(name) {
      return this.hasExtension(name, ['.jpg', '.jpeg', '.gif', '.png', '.bmp', '.svg', '.tiff', '.tif'])
    },
    hasExtension(name, exts) {
      return !_.isEmpty(exts) && (new RegExp('(' + exts.join('|').replace(/\./g, '\\.') + ')$', 'i')).test(name)
    },
    capitalize(string) {
      return string.charAt(0).toUpperCase() + string.slice(1)
    },
  }
}

export default funcs
