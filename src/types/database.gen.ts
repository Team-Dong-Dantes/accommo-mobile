export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      accommodation_amenities: {
        Row: {
          accommodation_id: string
          amenity: Database["public"]["Enums"]["amenity"]
        }
        Insert: {
          accommodation_id: string
          amenity: Database["public"]["Enums"]["amenity"]
        }
        Update: {
          accommodation_id?: string
          amenity?: Database["public"]["Enums"]["amenity"]
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_amenities_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_documents: {
        Row: {
          accommodation_id: string
          doc_type: string
          expires_at: string | null
          file_url: string
          id: string
          issued_at: string | null
          uploaded_at: string
          version: number
        }
        Insert: {
          accommodation_id: string
          doc_type: string
          expires_at?: string | null
          file_url: string
          id?: string
          issued_at?: string | null
          uploaded_at?: string
          version?: number
        }
        Update: {
          accommodation_id?: string
          doc_type?: string
          expires_at?: string | null
          file_url?: string
          id?: string
          issued_at?: string | null
          uploaded_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_documents_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_facilities: {
        Row: {
          access_scope: string
          accommodation_id: string
          description: string | null
          facility_type: string
          id: string
          label: string | null
          room_id: string | null
          sort_order: number
        }
        Insert: {
          access_scope: string
          accommodation_id: string
          description?: string | null
          facility_type: string
          id?: string
          label?: string | null
          room_id?: string | null
          sort_order?: number
        }
        Update: {
          access_scope?: string
          accommodation_id?: string
          description?: string | null
          facility_type?: string
          id?: string
          label?: string | null
          room_id?: string | null
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_facilities_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accommodation_facilities_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_facility_images: {
        Row: {
          facility_id: string
          id: string
          sort_order: number
          url: string
        }
        Insert: {
          facility_id: string
          id?: string
          sort_order?: number
          url: string
        }
        Update: {
          facility_id?: string
          id?: string
          sort_order?: number
          url?: string
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_facility_images_facility_id_fkey"
            columns: ["facility_id"]
            isOneToOne: false
            referencedRelation: "accommodation_facilities"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_images: {
        Row: {
          accommodation_id: string
          id: string
          sort_order: number | null
          url: string
        }
        Insert: {
          accommodation_id: string
          id?: string
          sort_order?: number | null
          url: string
        }
        Update: {
          accommodation_id?: string
          id?: string
          sort_order?: number | null
          url?: string
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_images_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_manager_profiles: {
        Row: {
          avg_response_minutes: number | null
          extracted_gov_id: string | null
          extracted_name: string | null
          government_id_url: string | null
          response_rate: number | null
          user_id: string
        }
        Insert: {
          avg_response_minutes?: number | null
          extracted_gov_id?: string | null
          extracted_name?: string | null
          government_id_url?: string | null
          response_rate?: number | null
          user_id: string
        }
        Update: {
          avg_response_minutes?: number | null
          extracted_gov_id?: string | null
          extracted_name?: string | null
          government_id_url?: string | null
          response_rate?: number | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_manager_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_manager_reviews: {
        Row: {
          accommodation_manager_id: string
          comment: string | null
          created_at: string
          id: string
          lease_id: string
          rating: number
          student_id: string
        }
        Insert: {
          accommodation_manager_id: string
          comment?: string | null
          created_at?: string
          id?: string
          lease_id: string
          rating: number
          student_id: string
        }
        Update: {
          accommodation_manager_id?: string
          comment?: string | null
          created_at?: string
          id?: string
          lease_id?: string
          rating?: number
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_manager_reviews_accommodation_manager_id_fkey"
            columns: ["accommodation_manager_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accommodation_manager_reviews_lease_id_fkey"
            columns: ["lease_id"]
            isOneToOne: false
            referencedRelation: "leases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accommodation_manager_reviews_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_policies: {
        Row: {
          accommodation_id: string
          advance_months: number | null
          contract_type: string | null
          cooking: boolean | null
          curfew_time: string | null
          deposit_months: number | null
          house_rules_json: Json | null
          laundry: boolean | null
          min_stay: number | null
          pets: boolean | null
          quiet_hours: string | null
          smoking: boolean | null
          visitor_policy: string | null
        }
        Insert: {
          accommodation_id: string
          advance_months?: number | null
          contract_type?: string | null
          cooking?: boolean | null
          curfew_time?: string | null
          deposit_months?: number | null
          house_rules_json?: Json | null
          laundry?: boolean | null
          min_stay?: number | null
          pets?: boolean | null
          quiet_hours?: string | null
          smoking?: boolean | null
          visitor_policy?: string | null
        }
        Update: {
          accommodation_id?: string
          advance_months?: number | null
          contract_type?: string | null
          cooking?: boolean | null
          curfew_time?: string | null
          deposit_months?: number | null
          house_rules_json?: Json | null
          laundry?: boolean | null
          min_stay?: number | null
          pets?: boolean | null
          quiet_hours?: string | null
          smoking?: boolean | null
          visitor_policy?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_policies_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: true
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_reviews: {
        Row: {
          accommodation_id: string
          comment: string | null
          created_at: string
          id: string
          lease_id: string
          rating: number
          student_id: string
        }
        Insert: {
          accommodation_id: string
          comment?: string | null
          created_at?: string
          id?: string
          lease_id: string
          rating: number
          student_id: string
        }
        Update: {
          accommodation_id?: string
          comment?: string | null
          created_at?: string
          id?: string
          lease_id?: string
          rating?: number
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_reviews_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accommodation_reviews_lease_id_fkey"
            columns: ["lease_id"]
            isOneToOne: false
            referencedRelation: "leases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accommodation_reviews_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodations: {
        Row: {
          accommodation_manager_id: string
          accommodation_type: string | null
          accreditation_expires_at: string | null
          accreditation_status: string | null
          accredited_at: string | null
          address: string | null
          barangay: string | null
          business_name: string | null
          capacity: number | null
          city: string | null
          description: string | null
          id: string
          lat: number | null
          lng: number | null
          name: string
          rating_avg: number | null
          reviews_count: number | null
          room_type: Database["public"]["Enums"]["room_type"] | null
          status: Database["public"]["Enums"]["accommodation_status"]
          total_floors: number | null
          total_rooms: number | null
        }
        Insert: {
          accommodation_manager_id: string
          accommodation_type?: string | null
          accreditation_expires_at?: string | null
          accreditation_status?: string | null
          accredited_at?: string | null
          address?: string | null
          barangay?: string | null
          business_name?: string | null
          capacity?: number | null
          city?: string | null
          description?: string | null
          id?: string
          lat?: number | null
          lng?: number | null
          name: string
          rating_avg?: number | null
          reviews_count?: number | null
          room_type?: Database["public"]["Enums"]["room_type"] | null
          status: Database["public"]["Enums"]["accommodation_status"]
          total_floors?: number | null
          total_rooms?: number | null
        }
        Update: {
          accommodation_manager_id?: string
          accommodation_type?: string | null
          accreditation_expires_at?: string | null
          accreditation_status?: string | null
          accredited_at?: string | null
          address?: string | null
          barangay?: string | null
          business_name?: string | null
          capacity?: number | null
          city?: string | null
          description?: string | null
          id?: string
          lat?: number | null
          lng?: number | null
          name?: string
          rating_avg?: number | null
          reviews_count?: number | null
          room_type?: Database["public"]["Enums"]["room_type"] | null
          status?: Database["public"]["Enums"]["accommodation_status"]
          total_floors?: number | null
          total_rooms?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "accommodations_accommodation_manager_id_fkey"
            columns: ["accommodation_manager_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      admin_profiles: {
        Row: {
          employee_id: string | null
          office: Database["public"]["Enums"]["office"]
          position: string | null
          user_id: string
        }
        Insert: {
          employee_id?: string | null
          office: Database["public"]["Enums"]["office"]
          position?: string | null
          user_id: string
        }
        Update: {
          employee_id?: string | null
          office?: Database["public"]["Enums"]["office"]
          position?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "admin_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      announcements: {
        Row: {
          archived: boolean
          audience: Database["public"]["Enums"]["audience_type"]
          author_id: string
          body: string
          expires_at: string | null
          id: string
          published_at: string | null
          title: string
        }
        Insert: {
          archived?: boolean
          audience?: Database["public"]["Enums"]["audience_type"]
          author_id: string
          body: string
          expires_at?: string | null
          id?: string
          published_at?: string | null
          title: string
        }
        Update: {
          archived?: boolean
          audience?: Database["public"]["Enums"]["audience_type"]
          author_id?: string
          body?: string
          expires_at?: string | null
          id?: string
          published_at?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "announcements_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_logs: {
        Row: {
          action: string
          actor_id: string | null
          after_json: Json | null
          before_json: Json | null
          created_at: string
          entity_id: string
          entity_type: string
          id: string
          ip_address: string | null
          user_agent: string | null
        }
        Insert: {
          action: string
          actor_id?: string | null
          after_json?: Json | null
          before_json?: Json | null
          created_at?: string
          entity_id: string
          entity_type: string
          id?: string
          ip_address?: string | null
          user_agent?: string | null
        }
        Update: {
          action?: string
          actor_id?: string | null
          after_json?: Json | null
          before_json?: Json | null
          created_at?: string
          entity_id?: string
          entity_type?: string
          id?: string
          ip_address?: string | null
          user_agent?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_logs_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      boarding_history: {
        Row: {
          accommodation_id: string
          accommodation_name: string | null
          end_reason: string | null
          id: string
          period_end: string
          period_start: string
          room_type: string | null
          student_id: string
        }
        Insert: {
          accommodation_id: string
          accommodation_name?: string | null
          end_reason?: string | null
          id?: string
          period_end: string
          period_start: string
          room_type?: string | null
          student_id: string
        }
        Update: {
          accommodation_id?: string
          accommodation_name?: string | null
          end_reason?: string | null
          id?: string
          period_end?: string
          period_start?: string
          room_type?: string | null
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "boarding_history_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boarding_history_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      concerns: {
        Row: {
          acknowledged_at: string | null
          category: string
          created_at: string
          description: string | null
          id: string
          lease_id: string
          manager_response: string | null
          reported_at: string
          resolved_at: string | null
          status: string
          updated_at: string
        }
        Insert: {
          acknowledged_at?: string | null
          category: string
          created_at?: string
          description?: string | null
          id?: string
          lease_id: string
          manager_response?: string | null
          reported_at?: string
          resolved_at?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          acknowledged_at?: string | null
          category?: string
          created_at?: string
          description?: string | null
          id?: string
          lease_id?: string
          manager_response?: string | null
          reported_at?: string
          resolved_at?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "concerns_lease_id_fkey"
            columns: ["lease_id"]
            isOneToOne: false
            referencedRelation: "leases"
            referencedColumns: ["id"]
          },
        ]
      }
      conversations: {
        Row: {
          id: string
          last_message: string | null
          last_time: string | null
          unread_a: number
          unread_b: number
          user_a_id: string
          user_b_id: string
        }
        Insert: {
          id?: string
          last_message?: string | null
          last_time?: string | null
          unread_a?: number
          unread_b?: number
          user_a_id: string
          user_b_id: string
        }
        Update: {
          id?: string
          last_message?: string | null
          last_time?: string | null
          unread_a?: number
          unread_b?: number
          user_a_id?: string
          user_b_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "conversations_user_a_id_fkey"
            columns: ["user_a_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_user_b_id_fkey"
            columns: ["user_b_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      leases: {
        Row: {
          accommodation_manager_id: string
          advance_paid: number | null
          deposit_paid: number | null
          end_date: string
          ended_reason: string | null
          id: string
          leave_requested_at: string | null
          monthly_rent: number | null
          room_id: string
          start_date: string
          status: Database["public"]["Enums"]["lease_status"]
          student_id: string
        }
        Insert: {
          accommodation_manager_id: string
          advance_paid?: number | null
          deposit_paid?: number | null
          end_date: string
          ended_reason?: string | null
          id?: string
          leave_requested_at?: string | null
          monthly_rent?: number | null
          room_id: string
          start_date: string
          status?: Database["public"]["Enums"]["lease_status"]
          student_id: string
        }
        Update: {
          accommodation_manager_id?: string
          advance_paid?: number | null
          deposit_paid?: number | null
          end_date?: string
          ended_reason?: string | null
          id?: string
          leave_requested_at?: string | null
          monthly_rent?: number | null
          room_id?: string
          start_date?: string
          status?: Database["public"]["Enums"]["lease_status"]
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "leases_accommodation_manager_id_fkey"
            columns: ["accommodation_manager_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "leases_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "leases_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      messages: {
        Row: {
          body: string
          conversation_id: string
          id: string
          sender_id: string
          sent_at: string
          status: Database["public"]["Enums"]["msg_status"]
        }
        Insert: {
          body: string
          conversation_id: string
          id?: string
          sender_id: string
          sent_at?: string
          status?: Database["public"]["Enums"]["msg_status"]
        }
        Update: {
          body?: string
          conversation_id?: string
          id?: string
          sender_id?: string
          sent_at?: string
          status?: Database["public"]["Enums"]["msg_status"]
        }
        Relationships: [
          {
            foreignKeyName: "messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          body: string
          created_at: string
          id: string
          link_url: string | null
          read_at: string | null
          title: string
          type: string
          user_id: string
        }
        Insert: {
          body: string
          created_at?: string
          id?: string
          link_url?: string | null
          read_at?: string | null
          title: string
          type: string
          user_id: string
        }
        Update: {
          body?: string
          created_at?: string
          id?: string
          link_url?: string | null
          read_at?: string | null
          title?: string
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          amount: number
          description: string | null
          id: string
          lease_id: string
          method: Database["public"]["Enums"]["payment_method"]
          month: string
          paid_at: string | null
          proof_url: string | null
          status: Database["public"]["Enums"]["payment_status"]
          txn_reference: string | null
          verified_by: string | null
        }
        Insert: {
          amount: number
          description?: string | null
          id?: string
          lease_id: string
          method: Database["public"]["Enums"]["payment_method"]
          month: string
          paid_at?: string | null
          proof_url?: string | null
          status?: Database["public"]["Enums"]["payment_status"]
          txn_reference?: string | null
          verified_by?: string | null
        }
        Update: {
          amount?: number
          description?: string | null
          id?: string
          lease_id?: string
          method?: Database["public"]["Enums"]["payment_method"]
          month?: string
          paid_at?: string | null
          proof_url?: string | null
          status?: Database["public"]["Enums"]["payment_status"]
          txn_reference?: string | null
          verified_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "payments_lease_id_fkey"
            columns: ["lease_id"]
            isOneToOne: false
            referencedRelation: "leases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_verified_by_fkey"
            columns: ["verified_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      policies: {
        Row: {
          archived: boolean
          body: string
          created_by: string
          effective_date: string
          id: string
          title: string
          version: string | null
        }
        Insert: {
          archived?: boolean
          body: string
          created_by: string
          effective_date: string
          id?: string
          title: string
          version?: string | null
        }
        Update: {
          archived?: boolean
          body?: string
          created_by?: string
          effective_date?: string
          id?: string
          title?: string
          version?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "policies_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      room_images: {
        Row: {
          id: string
          room_id: string
          sort_order: number | null
          url: string
        }
        Insert: {
          id?: string
          room_id: string
          sort_order?: number | null
          url: string
        }
        Update: {
          id?: string
          room_id?: string
          sort_order?: number | null
          url?: string
        }
        Relationships: [
          {
            foreignKeyName: "room_images_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id"]
          },
        ]
      }
      rooms: {
        Row: {
          accommodation_id: string
          capacity: number | null
          current_pax: number | null
          custom_room_type: string | null
          floor: number | null
          id: string
          label: string | null
          monthly_rent: number | null
          room_number: string | null
          room_type: string | null
          status: Database["public"]["Enums"]["room_status"]
        }
        Insert: {
          accommodation_id: string
          capacity?: number | null
          current_pax?: number | null
          custom_room_type?: string | null
          floor?: number | null
          id?: string
          label?: string | null
          monthly_rent?: number | null
          room_number?: string | null
          room_type?: string | null
          status: Database["public"]["Enums"]["room_status"]
        }
        Update: {
          accommodation_id?: string
          capacity?: number | null
          current_pax?: number | null
          custom_room_type?: string | null
          floor?: number | null
          id?: string
          label?: string | null
          monthly_rent?: number | null
          room_number?: string | null
          room_type?: string | null
          status?: Database["public"]["Enums"]["room_status"]
        }
        Relationships: [
          {
            foreignKeyName: "rooms_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
        ]
      }
      student_profiles: {
        Row: {
          assessment_of_fees_url: string | null
          college: string | null
          emergency_contact_json: Json | null
          extracted_name: string | null
          extracted_school_id: string | null
          osas_verified_at: string | null
          program: string | null
          qr_code_token: string | null
          school_id_url: string | null
          student_id: string | null
          user_id: string
          year_level: number | null
        }
        Insert: {
          assessment_of_fees_url?: string | null
          college?: string | null
          emergency_contact_json?: Json | null
          extracted_name?: string | null
          extracted_school_id?: string | null
          osas_verified_at?: string | null
          program?: string | null
          qr_code_token?: string | null
          school_id_url?: string | null
          student_id?: string | null
          user_id: string
          year_level?: number | null
        }
        Update: {
          assessment_of_fees_url?: string | null
          college?: string | null
          emergency_contact_json?: Json | null
          extracted_name?: string | null
          extracted_school_id?: string | null
          osas_verified_at?: string | null
          program?: string | null
          qr_code_token?: string | null
          school_id_url?: string | null
          student_id?: string | null
          user_id?: string
          year_level?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "student_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      tenant_reviews: {
        Row: {
          accommodation_manager_id: string
          comment: string | null
          created_at: string
          id: string
          lease_id: string
          rating: number
          student_id: string
        }
        Insert: {
          accommodation_manager_id: string
          comment?: string | null
          created_at?: string
          id?: string
          lease_id: string
          rating: number
          student_id: string
        }
        Update: {
          accommodation_manager_id?: string
          comment?: string | null
          created_at?: string
          id?: string
          lease_id?: string
          rating?: number
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tenant_reviews_accommodation_manager_id_fkey"
            columns: ["accommodation_manager_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tenant_reviews_lease_id_fkey"
            columns: ["lease_id"]
            isOneToOne: false
            referencedRelation: "leases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tenant_reviews_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      ticket_messages: {
        Row: {
          attachment_urls: string[]
          author_id: string | null
          author_role: string
          body: string
          created_at: string
          id: string
          is_internal: boolean
          ticket_id: string
        }
        Insert: {
          attachment_urls?: string[]
          author_id?: string | null
          author_role?: string
          body: string
          created_at?: string
          id?: string
          is_internal?: boolean
          ticket_id: string
        }
        Update: {
          attachment_urls?: string[]
          author_id?: string | null
          author_role?: string
          body?: string
          created_at?: string
          id?: string
          is_internal?: boolean
          ticket_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ticket_messages_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ticket_messages_ticket_id_fkey"
            columns: ["ticket_id"]
            isOneToOne: false
            referencedRelation: "tickets"
            referencedColumns: ["id"]
          },
        ]
      }
      tickets: {
        Row: {
          accommodation_id: string | null
          accommodation_manager_id: string | null
          assignee_id: string | null
          category: string | null
          description: string | null
          id: string
          lease_id: string | null
          photo_urls: string[]
          priority: string
          reported_at: string
          reporter_name: string | null
          resolved_at: string | null
          status: string
          student_id: string | null
          subject: string | null
          updated_at: string
        }
        Insert: {
          accommodation_id?: string | null
          accommodation_manager_id?: string | null
          assignee_id?: string | null
          category?: string | null
          description?: string | null
          id?: string
          lease_id?: string | null
          photo_urls?: string[]
          priority?: string
          reported_at?: string
          reporter_name?: string | null
          resolved_at?: string | null
          status?: string
          student_id?: string | null
          subject?: string | null
          updated_at?: string
        }
        Update: {
          accommodation_id?: string | null
          accommodation_manager_id?: string | null
          assignee_id?: string | null
          category?: string | null
          description?: string | null
          id?: string
          lease_id?: string | null
          photo_urls?: string[]
          priority?: string
          reported_at?: string
          reporter_name?: string | null
          resolved_at?: string | null
          status?: string
          student_id?: string | null
          subject?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "tickets_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tickets_accommodation_manager_id_fkey"
            columns: ["accommodation_manager_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tickets_assignee_id_fkey"
            columns: ["assignee_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tickets_lease_id_fkey"
            columns: ["lease_id"]
            isOneToOne: false
            referencedRelation: "leases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tickets_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      users: {
        Row: {
          avatar_color: string | null
          created_at: string | null
          email: string
          email_verified_at: string | null
          full_name: string
          id: string
          initials: string
          is_superadmin: boolean
          last_login_at: string | null
          onboarding_complete: boolean
          phone: string
          role: Database["public"]["Enums"]["user_role"]
          sex: string | null
          status: Database["public"]["Enums"]["user_status"]
          updated_at: string | null
        }
        Insert: {
          avatar_color?: string | null
          created_at?: string | null
          email: string
          email_verified_at?: string | null
          full_name: string
          id: string
          initials: string
          is_superadmin?: boolean
          last_login_at?: string | null
          onboarding_complete?: boolean
          phone: string
          role: Database["public"]["Enums"]["user_role"]
          sex?: string | null
          status?: Database["public"]["Enums"]["user_status"]
          updated_at?: string | null
        }
        Update: {
          avatar_color?: string | null
          created_at?: string | null
          email?: string
          email_verified_at?: string | null
          full_name?: string
          id?: string
          initials?: string
          is_superadmin?: boolean
          last_login_at?: string | null
          onboarding_complete?: boolean
          phone?: string
          role?: Database["public"]["Enums"]["user_role"]
          sex?: string | null
          status?: Database["public"]["Enums"]["user_status"]
          updated_at?: string | null
        }
        Relationships: []
      }
      verification_documents: {
        Row: {
          doc_type: string | null
          file_url: string | null
          filename: string | null
          id: string
          status: Database["public"]["Enums"]["doc_status"]
          uploaded_at: string | null
          user_id: string | null
          verified_at: string | null
          verified_by: string | null
        }
        Insert: {
          doc_type?: string | null
          file_url?: string | null
          filename?: string | null
          id?: string
          status?: Database["public"]["Enums"]["doc_status"]
          uploaded_at?: string | null
          user_id?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Update: {
          doc_type?: string | null
          file_url?: string | null
          filename?: string | null
          id?: string
          status?: Database["public"]["Enums"]["doc_status"]
          uploaded_at?: string | null
          user_id?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "verification_documents_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "verification_documents_verified_by_fkey"
            columns: ["verified_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      latest_accommodation_documents: {
        Row: {
          accommodation_id: string | null
          doc_type: string | null
          expires_at: string | null
          file_url: string | null
          issued_at: string | null
          uploaded_at: string | null
          version: number | null
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_documents_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      can_notify: { Args: { target: string }; Returns: boolean }
      check_student_id_exists: {
        Args: { p_student_id: string }
        Returns: boolean
      }
      current_is_superadmin: { Args: never; Returns: boolean }
      get_my_role: { Args: never; Returns: string }
      get_verification_queue: {
        Args: never
        Returns: {
          created_at: string
          doc_status: string
          doc_type: string
          email: string
          file_url: string
          filename: string
          full_name: string
          role: string
          user_id: string
          user_status: string
        }[]
      }
      is_admin: { Args: { p_uid: string }; Returns: boolean }
      mark_conversation_read: {
        Args: { p_conversation: string }
        Returns: undefined
      }
      notify_admins: {
        Args: {
          p_body: string
          p_link_url: string
          p_title: string
          p_type: string
        }
        Returns: undefined
      }
      resubmit_verification: { Args: never; Returns: undefined }
      set_audit_context: {
        Args: { p_ip_address?: string; p_user_agent?: string }
        Returns: undefined
      }
    }
    Enums: {
      accommodation_status:
        | "pending"
        | "reviewing"
        | "accredited"
        | "rejected"
        | "delisted"
      amenity:
        | "wifi"
        | "water"
        | "electric"
        | "aircon"
        | "parking"
        | "kitchen"
        | "laundry"
        | "cctv"
      audience_type: "all" | "students" | "accommodation_managers"
      doc_status: "pending" | "approved" | "rejected"
      lease_status:
        | "active"
        | "ended"
        | "terminated"
        | "leave_requested"
        | "pending"
        | "rejected"
      msg_status: "sent" | "delivered" | "read"
      office: "osas" | "registrar" | "housing"
      payment_method: "gcash" | "maya" | "bank" | "cash" | "others"
      payment_status: "due" | "paid" | "overdue" | "pending_verification"
      room_status: "available" | "occupied" | "maintenance"
      room_type: "solo" | "duo" | "triple" | "bedspace" | "studio"
      user_role: "student" | "accommodation_manager" | "admin"
      user_status:
        | "unverified"
        | "pending"
        | "reviewing"
        | "verified"
        | "rejected"
        | "suspended"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      accommodation_status: [
        "pending",
        "reviewing",
        "accredited",
        "rejected",
        "delisted",
      ],
      amenity: [
        "wifi",
        "water",
        "electric",
        "aircon",
        "parking",
        "kitchen",
        "laundry",
        "cctv",
      ],
      audience_type: ["all", "students", "accommodation_managers"],
      doc_status: ["pending", "approved", "rejected"],
      lease_status: [
        "active",
        "ended",
        "terminated",
        "leave_requested",
        "pending",
        "rejected",
      ],
      msg_status: ["sent", "delivered", "read"],
      office: ["osas", "registrar", "housing"],
      payment_method: ["gcash", "maya", "bank", "cash", "others"],
      payment_status: ["due", "paid", "overdue", "pending_verification"],
      room_status: ["available", "occupied", "maintenance"],
      room_type: ["solo", "duo", "triple", "bedspace", "studio"],
      user_role: ["student", "accommodation_manager", "admin"],
      user_status: [
        "unverified",
        "pending",
        "reviewing",
        "verified",
        "rejected",
        "suspended",
      ],
    },
  },
} as const
