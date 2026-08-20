export const validationRules = {
  email: (value: string): boolean => {
    if (!value) return false
    const emailRegex = /^[^\s@]+@gmail\.com$/
    return emailRegex.test(value.toLowerCase())
  },

  positiveNumber: (value: string | number): boolean => {
    const num = typeof value === 'string' ? parseFloat(value) : value
    return !isNaN(num) && num > 0
  },

  phoneNumber: (value: string): boolean => {
    const phoneRegex = /^(\+63|0)[0-9]{9,10}$/
    return phoneRegex.test(value.replace(/\s/g, ''))
  },

  propertyName: (value: string): boolean => {
    if (!value) return false
    const trimmed = value.trim()
    return trimmed.length >= 3 && trimmed.length <= 100
  },

  address: (value: string): boolean => {
    if (!value) return false
    const trimmed = value.trim()
    return trimmed.length >= 5 && trimmed.length <= 255
  },
}

export const getValidationMessage = (field: string, rule: string): string => {
  const messages: Record<string, Record<string, string>> = {
    email: {
      email: 'Must be a valid Gmail address (e.g., user@gmail.com)',
    },
    rent: {
      positiveNumber: 'Monthly rent must be a positive number',
    },
    capacity: {
      positiveNumber: 'Capacity must be a positive number',
    },
    phone: {
      phoneNumber: 'Must be a valid Philippine phone number',
    },
    name: {
      propertyName: 'Property name must be between 3 and 100 characters',
    },
    address: {
      address: 'Address must be between 5 and 255 characters',
    },
  }

  return messages[field]?.[rule] || 'Invalid input'
}
