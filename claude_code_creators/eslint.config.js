export default [
  {
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: {
        window: "readonly",
        document: "readonly",
        console: "readonly",
        fetch: "readonly",
        setTimeout: "readonly",
        clearTimeout: "readonly",
        jest: "readonly"
      }
    },
    rules: {
      "no-unused-vars": "warn",
      "no-console": "warn",
      "semi": ["error", "never"],
      "quotes": ["error", "double"],
      "indent": ["error", 2]
    },
    files: ["**/*.js"]
  }
];