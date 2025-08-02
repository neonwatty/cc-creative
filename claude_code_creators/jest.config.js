export default {
  preset: null,
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['<rootDir>/test/javascript/setup.js'],
  testMatch: ['<rootDir>/test/javascript/**/*_test.js'],
  moduleFileExtensions: ['js', 'mjs'],
  transform: {
    "^.+\\.js$": "babel-jest"
  },
  moduleNameMapper: {
    '^@hotwired/stimulus$': '<rootDir>/test/javascript/stimulus_mock.js'
  },
  transformIgnorePatterns: [
    "node_modules/(?!(@hotwired/stimulus)/)"
  ]
};