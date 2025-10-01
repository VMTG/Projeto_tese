import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://iytncyrlqrpqovvtqznx.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5dG5jeXJscXJwcW92dnRxem54Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgyNzQ0MjEsImV4cCI6MjA3Mzg1MDQyMX0.PcQUJm6xqNwnmGx1yPfSBoACGsO8K0KcRBwNa-jBfzw';

export const supabase = createClient(supabaseUrl, supabaseKey);