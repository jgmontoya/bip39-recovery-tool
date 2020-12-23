require 'openssl'
require_relative 'bip39_wordlist.rb'

# ORIGINAL = ['dad', 'century', 'mule', 'syrup', 'keep', 'tonight',
#                'quick', 'budget', 'employ', 'you', 'usual', 'share']

ONE_MISSING = ['', 'century', '', 'syrup', 'keep', 'tonight',
               'quick', 'budget', 'employ', 'you', 'usual', 'share']

class SimpleBip32Solver
  def initialize(word_list)
    @word_list = word_list
  end

  def solve
    candidate_words_indexes = [0] * number_of_missing_words
    possible_words = []
    until candidate_words_indexes == [WORDLIST.length - 1] * number_of_missing_words
      if try_candidates(candidate_words_indexes)
        possible_words << (candidate_words_indexes.map { |index| WORDLIST[index] })
      end
      candidate_words_indexes = increment_candidate_indexes(candidate_words_indexes)
    end
    possible_words
  end

  def increment_candidate_indexes(candidate_words_indexes)
    carry = 1
    candidate_words_indexes.map do |word_index|
      next_carry = (word_index + carry) / WORDLIST.length
      res = (word_index + carry) % WORDLIST.length
      carry = next_carry
      res
    end
  end

  def try_candidates(candidate_words_indexes)
    preproc_copy = preprocessed_wordlist.clone
    candidates_binary = candidate_words_indexes.map { |index| index.to_s(2).rjust(11, '0') }
    entropy_binary = preproc_copy.first.empty? ? candidates_binary.shift : ''
    until candidates_binary.empty? && preproc_copy.empty?
      entropy_binary += preproc_copy.shift unless preproc_copy.empty?
      entropy_binary += candidates_binary.shift unless candidates_binary.empty?
    end
    calc_checksum(entropy_binary) == target_checksum
  end

  def preprocessed_wordlist
    @preprocessed_wordlist ||= preprocess_wordlist
  end

  def preprocess_wordlist
    result = splitted_wordlist
    result[-1] = splitted_wordlist.last.slice(0, result.last.length - target_checksum.length)
    result
  end

  def splitted_wordlist
    @splitted_wordlist ||= split_wordlist
  end

  def split_wordlist
    result = []
    buffer = ''
    @word_list.each do |word|
      binary = word2binary(word)
      binary ? buffer += binary : result << buffer
      buffer = '' unless binary
    end
    result << buffer
  end

  def number_of_missing_words
    @word_list.count('')
  end

  def target_checksum
    @target_checksum ||= splitted_wordlist.last.slice(-entropy_binary_length / 32,
                                                      entropy_binary_length / 32)
  end

  def entropy_binary_length
    @entropy_binary_length ||= @word_list.length * 11 * 32 / 33
  end

  def word2binary(word)
    word2num(word)&.to_s(2)&.rjust(11, '0')
  end

  def word2num(word)
    WORDLIST.index(word)
  end

  def calc_checksum(entropy_binary)
    sha256hash = OpenSSL::Digest::SHA256.hexdigest([entropy_binary].pack('B*'))
    sha256hash_binary = [sha256hash].pack('H*').unpack1('B*')
    sha256hash_binary.slice(0, (entropy_binary.length / 32))
  end
end

solver = SimpleBip32Solver.new ONE_MISSING

p solution = solver.solve
p solution.length
