#include "matmul.h"
#include "../utils/timer.h"

namespace troy { namespace linear {

    using uint128_t = __uint128_t;

    #define D_IMPL_ALL                                               \
        D_IMPL(BatchEncoderAdapter, uint64_t)                        \
        D_IMPL(CKKSEncoderAdapter, double)                           \
        D_IMPL(PolynomialEncoderRing2kAdapter<uint32_t>, uint32_t)   \
        D_IMPL(PolynomialEncoderRing2kAdapter<uint64_t>, uint64_t)   \
        D_IMPL(PolynomialEncoderRing2kAdapter<uint128_t>, uint128_t)

    void MatmulHelper::determine_block() {
        size_t b_best = 0, i_best = 0, o_best = 0;
        size_t c_best = 2147483647;
        if (!pack_lwe) {
            for (size_t b = batch_size; b >= 1; b--) {
                size_t bc = ceil_div(batch_size, b);
                if (b >= slot_count) continue;
                if (bc * 2 > c_best) continue;
                for (size_t i = 1; i < slot_count / b; i++) {
                    size_t o = slot_count / b / i;
                    if (o > output_dims) o = output_dims;
                    if (i > input_dims) continue;
                    if (o < 1) continue;
                    size_t c = 0;
                    if (objective == MatmulObjective::EncryptLeft) {
                        c = bc * (ceil_div(input_dims, i) + ceil_div(output_dims, o));
                    } else if (objective == MatmulObjective::EncryptRight) {
                        c = (bc + ceil_div(input_dims, i)) * ceil_div(output_dims, o);
                    } else if (objective == MatmulObjective::Crossed) {
                        c = bc * input_dims + (bc + ceil_div(input_dims, i)) * ceil_div(output_dims, o);
                    } else {
                        throw std::runtime_error("[MatmulHelper::determine_block] Invalid objective");
                    }
                    if (c >= c_best) continue;
                    b_best = b; i_best = i; o_best = o; c_best = c;
                }
            }
        } else {
            double sqrtn = std::pow(slot_count, 0.33);
            size_t i = 1; while (i * 2 < sqrtn) {i *= 2;}
            if (i > input_dims) {
                i = 1; while (i < input_dims) i *= 2;
            }
            
            for (size_t b = 1; b <= batch_size; b++) {
                size_t bc = ceil_div(batch_size, b);
                if (b > slot_count) {continue;}
                size_t o = slot_count / b / i;
                if (o > output_dims) {o = output_dims;}
                if (o < 1) {continue;}
                size_t c = 0;
                if (objective == MatmulObjective::EncryptLeft) {
                    c = bc * ceil_div(input_dims, i);
                    c += ceil_div(bc * ceil_div(output_dims, o), i);
                } else if (objective == MatmulObjective::EncryptRight) {
                    c = ceil_div(output_dims, o) * ceil_div(input_dims, i);
                    c += ceil_div(bc * ceil_div(output_dims, o), i);
                } else if (objective == MatmulObjective::Crossed) {
                    c = bc * ceil_div(input_dims, i);
                    c += ceil_div(output_dims, o) * ceil_div(input_dims, i);
                    c += ceil_div(bc * ceil_div(output_dims, o), i);
                } else {
                    throw std::runtime_error("MatmulHelper: invalid objective");
                }
                if (c >= c_best) {continue;}
                b_best = b; i_best = i; o_best = o; c_best = c;
            }

        }
        batch_block = b_best;
        input_block = i_best;
        output_block = o_best;
        // printf("block (%zu, %zu, %zu) -> (%zu, %zu, %zu)\n", batch_size, input_dims, output_dims, batch_block, input_block, output_block);
    }
    
    template <typename E, typename T>
    Plaintext MatmulHelper::encode_weights_small(
        const E& encoder, const T* weights,
        size_t li, size_t ui, size_t lj, size_t uj, bool for_cipher
    ) const {
        std::vector<T> vec(input_block * output_block, 0);
        for (size_t j = lj; j < uj; j++) {
            for (size_t i = li; i < ui; i++) {
                size_t r = (j-lj) * input_block + input_block - (i-li) - 1;
                assert(r < slot_count);
                vec[r] = weights[i * output_dims + j];
            }
        }
        Plaintext p = for_cipher ? encoder.encode_for_cipher(vec, pool) : encoder.encode_for_plain(vec, pool);
        if (store_in_host) p.to_host_inplace();
        return p;
    }

    #define D_IMPL(adapter, dtype)                                               \
        template Plaintext MatmulHelper::encode_weights_small<adapter, dtype>(   \
            const adapter& encoder, const dtype* weights,                        \
            size_t li, size_t ui, size_t lj, size_t uj, bool for_cipher          \
        ) const;       
    D_IMPL_ALL
    #undef D_IMPL

    template <typename E, typename T>
    void MatmulHelper::encode_weights(const E& encoder, const Encryptor* encryptor, const T* weights, bool for_cipher, Plain2d* out_plain, Cipher2d* out_cipher) const {
        size_t height = input_dims, width = output_dims;
        size_t h = input_block, w = output_block;
        if (out_plain) {
            *out_plain = Plain2d();
            out_plain->data().clear();
            out_plain->data().reserve(ceil_div(height, h));
        } else {
            if (!out_cipher || !encryptor) throw std::invalid_argument("[MatmulHelper::encode_weights] Both out_plain and out_cipher are null.");
            *out_cipher = Cipher2d();
            out_cipher->data().clear();
            out_cipher->data().reserve(ceil_div(height, h));
        }
        for (size_t li = 0; li < height; li += h) {
            size_t ui = (li + h > height) ? height : (li + h);
            std::vector<Plaintext> encoded_row_plain; encoded_row_plain.reserve(ceil_div(width, w));
            std::vector<Ciphertext> encoded_row_cipher; encoded_row_cipher.reserve(ceil_div(width, w));
            for (size_t lj = 0; lj < width; lj += w) {
                size_t uj = (lj + w > width) ? width : (lj + w);
                if (out_plain) {
                    encoded_row_plain.push_back(this->encode_weights_small(encoder, weights, li, ui, lj, uj, for_cipher));
                    if (store_in_host) encoded_row_plain.back().to_host_inplace();
                } else {
                    Plaintext p = this->encode_weights_small(encoder, weights, li, ui, lj, uj, for_cipher);
                    encoded_row_cipher.push_back(encryptor->encrypt_symmetric_new(p, true, nullptr, pool));
                    if (store_in_host) encoded_row_cipher.back().to_host_inplace();
                }
            }
            if (out_plain) out_plain->data().push_back(std::move(encoded_row_plain));
            else out_cipher->data().push_back(std::move(encoded_row_cipher));
        }
    }

    #define D_IMPL(adapter, dtype) \
        template void MatmulHelper::encode_weights<adapter, dtype>( \
            const adapter& encoder, const Encryptor* encryptor, const dtype* weights, bool for_cipher, Plain2d* out_plain, Cipher2d* out_cipher \
        ) const;
    D_IMPL_ALL
    #undef D_IMPL

    template <typename E, typename T>
    Plaintext MatmulHelper::encode_inputs_small(
        const E& encoder, const T* inputs,
        size_t li, size_t ui, size_t lj, size_t uj, bool for_cipher
    ) const {
        std::vector<T> vec(slot_count, 0);
        for (size_t j = lj; j < uj; j++) {
            for (size_t i = li; i < ui; i++) {
                size_t r = (i - li) * input_block * output_block + (j - lj);
                assert(r < slot_count);
                vec[r] = inputs[i * input_dims + j];
            }
        }
        Plaintext p = for_cipher ? encoder.encode_for_cipher(vec, pool) : encoder.encode_for_plain(vec, pool);
        if (store_in_host) p.to_host_inplace();
        return p;
    }

    #define D_IMPL(adapter, dtype)                                               \
        template Plaintext MatmulHelper::encode_inputs_small<adapter, dtype>(    \
            const adapter& encoder, const dtype* inputs,                         \
            size_t li, size_t ui, size_t lj, size_t uj, bool for_cipher          \
        ) const;
    D_IMPL_ALL
    #undef D_IMPL


    template <typename E, typename T>
    void MatmulHelper::encode_inputs(const E& encoder, const Encryptor* encryptor, const T* inputs, bool for_cipher, Plain2d* out_plain, Cipher2d* out_cipher) const {
        size_t vecsize = input_block;
        if (out_plain) {
            *out_plain = Plain2d();
            out_plain->data().clear();
            out_plain->data().reserve(batch_size);
        } else {
            if (!out_cipher || !encryptor) throw std::invalid_argument("[MatmulHelper::encode_inputs] Both out_plain and out_cipher are null.");
            *out_cipher = Cipher2d();
            out_cipher->data().clear();
            out_cipher->data().reserve(batch_size);
        }
        for (size_t li = 0; li < batch_size; li += batch_block) {
            size_t ui = (li + batch_block > batch_size) ? batch_size : li + batch_block;
            std::vector<Plaintext> encoded_row_plain;
            std::vector<Ciphertext> encoded_row_cipher;
            encoded_row_plain.reserve(ceil_div(input_dims, vecsize));
            encoded_row_cipher.reserve(ceil_div(input_dims, vecsize));
            for (size_t lj = 0; lj < input_dims; lj += vecsize) {
                size_t uj = (lj + vecsize > input_dims) ? input_dims : lj + vecsize;
                if (out_plain) {
                    encoded_row_plain.push_back(this->encode_inputs_small(encoder, inputs, li, ui, lj, uj, for_cipher));
                    if (store_in_host) encoded_row_plain.back().to_host_inplace();
                } else {
                    Plaintext p = this->encode_inputs_small(encoder, inputs, li, ui, lj, uj, for_cipher);
                    encoded_row_cipher.push_back(encryptor->encrypt_symmetric_new(p, true, nullptr, pool));
                    if (store_in_host) encoded_row_cipher.back().to_host_inplace();
                }
            }
            if (out_plain) out_plain->data().push_back(std::move(encoded_row_plain));
            else out_cipher->data().push_back(std::move(encoded_row_cipher));
        }
    }

    #define D_IMPL(adapter, dtype) \
        template void MatmulHelper::encode_inputs<adapter, dtype>( \
            const adapter& encoder, const Encryptor* encryptor, const dtype* inputs, bool for_cipher, Plain2d* out_plain, Cipher2d* out_cipher \
        ) const;
    D_IMPL_ALL
    #undef D_IMPL


    Cipher2d MatmulHelper::matmul(const Evaluator& evaluator, const Cipher2d& a, const Plain2d& w) const {
        Cipher2d ret; ret.data().resize(ceil_div(batch_size, batch_block));
        size_t output_vector_count = ceil_div(output_dims, output_block);
        for (size_t i = 0; i < ret.data().size(); i++) ret[i].resize(output_vector_count);
        if (a.data().size() != ceil_div(batch_size, batch_block)) {
            throw std::invalid_argument("[MatmulHelper::matmul] Input batch_size incorrect.");
        }
        if (w.data().size() != ceil_div(input_dims, input_block)) {
            throw std::invalid_argument("[MatmulHelper::matmul] Weight input dimension incorrect.");
        }
        for (size_t i = 0; i < w.data().size(); i++) {
            for (size_t j = 0; j < w[i].size(); j++) {
                const Plaintext* w_ptr = &w[i][j];
                Plaintext w_cloned;
                if (evaluator.on_device() && !w_ptr->on_device()) {
                    w_cloned = w_ptr->clone(pool);
                    w_ptr = &w_cloned;
                }
                for (size_t b = 0; b < ceil_div(batch_size, batch_block); b++) {
                    Ciphertext prod;
                    evaluator.multiply_plain(a[b][i], *w_ptr, prod, pool);
                    if (i==0) ret[b][j] = std::move(prod);
                    else {
                        evaluator.add_inplace(ret[b][j], prod, pool);
                    }
                }
            }
        }
        return ret;
    }

    Cipher2d MatmulHelper::matmul_cipher(const Evaluator& evaluator, const Cipher2d& a, const Cipher2d& w) const {
        Cipher2d ret; ret.data().reserve(ceil_div(batch_size, batch_block));
        size_t outputVectorCount = ceil_div(output_dims, output_block);
        if (a.data().size() != ceil_div(batch_size, batch_block)) {
            throw std::invalid_argument("[MatmulHelper::matmul_cipher] Input batch_size incorrect.");
        }
        if (w.data().size() != ceil_div(input_dims, input_block)) {
            throw std::invalid_argument("[MatmulHelper::matmul_cipher] Weight input dimension incorrect.");
        }
        for (size_t b = 0; b < ceil_div(batch_size, batch_block); b++) {
            std::vector<Ciphertext> outVecs(outputVectorCount);
            for (size_t i = 0; i < w.data().size(); i++) {
                for (size_t j = 0; j < w[i].size(); j++) {
                    Ciphertext prod;
                    evaluator.multiply(a[b][i], w[i][j], prod, pool);
                    if (i==0) outVecs[j] = std::move(prod);
                    else {
                        evaluator.add_inplace(outVecs[j], prod, pool);
                    }
                }
            }
            ret.data().push_back(std::move(outVecs));
        }
        return ret;
    }

    Cipher2d MatmulHelper::matmul_reverse(const Evaluator& evaluator, const Plain2d& a, const Cipher2d& w) const {
        Cipher2d ret; ret.data().reserve(ceil_div(batch_size, batch_block));
        size_t outputVectorCount = ceil_div(output_dims, output_block);
        if (a.data().size() != ceil_div(batch_size, batch_block)) {
            throw std::invalid_argument("[MatmulHelper::matmul_reverse] Input batch_size incorrect.");
        }
        if (w.data().size() != ceil_div(input_dims, input_block)) {
            throw std::invalid_argument("[MatmulHelper::matmul_reverse] Weight input dimension incorrect.");
        }
        for (size_t b = 0; b < ceil_div(batch_size, batch_block); b++) {
            std::vector<Ciphertext> outVecs(outputVectorCount);
            for (size_t i = 0; i < w.data().size(); i++) {
                const Plaintext* a_ptr = &a[b][i];
                Plaintext a_cloned;
                if (!a_ptr->on_device() && evaluator.on_device()) {
                    a_cloned = a_ptr->clone(pool);
                    a_ptr = &a_cloned;
                }
                for (size_t j = 0; j < w[i].size(); j++) {
                    Ciphertext prod;
                    evaluator.multiply_plain(w[i][j], *a_ptr, prod, pool);
                    if (i==0) outVecs[j] = std::move(prod);
                    else {
                        evaluator.add_inplace(outVecs[j], prod, pool);
                    }
                }
            }
            ret.data().push_back(std::move(outVecs));
        }
        return ret;
    }

    template <typename E, typename T>
    Plain2d MatmulHelper::encode_outputs(const E& encoder, const T* outputs) const {
        size_t vecsize = output_block;
        if (!this->pack_lwe) {
            Plain2d ret; ret.data().reserve(batch_size);
            for (size_t li = 0; li < batch_size; li += batch_block) {
                size_t ui = (li + batch_block > batch_size) ? batch_size : (li + batch_block);
                std::vector<Plaintext> encoded_row;
                encoded_row.reserve(ceil_div(output_dims, vecsize));
                for (size_t lj = 0; lj < output_dims; lj += vecsize) {
                    size_t uj = (lj + vecsize > output_dims) ? output_dims : (lj + vecsize);
                    std::vector<T> buffer(slot_count, 0);
                    for (size_t i = li; i < ui; i++)
                        for (size_t j = lj; j < uj; j++) 
                            buffer[(i - li) * input_block * output_block + (j - lj) * input_block + input_block - 1] = outputs[i * output_dims + j];
                    Plaintext pt = encoder.encode_for_cipher(buffer, pool);
                    if (store_in_host) pt.to_host_inplace();
                    encoded_row.push_back(std::move(pt));
                }
                ret.data().push_back(std::move(encoded_row));
            }
            return ret;
        } else {
            Plain2d plain2d; plain2d.data().reserve(batch_size);
            plain2d.data().push_back(std::vector<Plaintext>());
            size_t batch_block_count = ceil_div(this->batch_size, this->batch_block);
            size_t output_block_count = ceil_div(this->output_dims, this->output_block);
            auto ret = std::vector<std::vector<T>>(ceil_div(batch_block_count * output_block_count, this->input_block), std::vector<T>(this->slot_count, 0)); 
            size_t li = 0; size_t di = 0; while (li < this->batch_size) {
                size_t ui = std::min(this->batch_size, li + this->batch_block);
                size_t lj = 0; size_t dj = 0; while (lj < this->output_dims) {
                    size_t uj = std::min(this->output_dims, lj + vecsize);
                    size_t cipherId = di * ceil_div(this->output_dims, this->output_block) + dj;
                    size_t packedId = cipherId / this->input_block;
                    size_t packedOffset = cipherId % this->input_block;
                    for (size_t i = li; i < ui; i++) {
                        for (size_t j = lj; j < uj; j++) {
                            ret[packedId][(i - li) * this->input_block * this->output_block + (j - lj) * this->input_block + packedOffset] 
                                = outputs[i * this->output_dims + j];
                        }
                    }
                    dj += 1;
                    lj += vecsize; 
                }
                di += 1;
                li += this->batch_block;
            }
            plain2d.data()[0].reserve(ret.size());
            for (size_t i = 0; i < ret.size(); i++) {
                Plaintext pt = encoder.encode_for_cipher(ret[i], pool);
                if (store_in_host) pt.to_host_inplace();
                plain2d.data()[0].push_back(std::move(pt));
            }
            return plain2d;
        }
    }

    #define D_IMPL(adapter, dtype)                                               \
        template Plain2d MatmulHelper::encode_outputs<adapter, dtype>(           \
            const adapter& encoder, const dtype* outputs                         \
        ) const;
    D_IMPL_ALL
    #undef D_IMPL

    template <typename E, typename T>
    std::vector<T> MatmulHelper::decrypt_outputs(const E& encoder, const Decryptor& decryptor, const Cipher2d& outputs) const {
        std::vector<T> dec(batch_size * output_dims);
        size_t vecsize = output_block;
        Plaintext pt;
        if (!this->pack_lwe) {
            size_t di = 0;
            for (size_t li = 0; li < batch_size; li += batch_block) {
                size_t ui = (li + batch_block > batch_size) ? batch_size : (li + batch_block);
                size_t dj = 0;
                for (size_t lj = 0; lj < output_dims; lj += vecsize) {
                    size_t uj = (lj + vecsize > output_dims) ? output_dims : (lj + vecsize);
                    const Ciphertext* c = &outputs[di][dj];
                    Ciphertext c_cloned;
                    if (decryptor.on_device() && !c->on_device()) {
                        c_cloned = c->clone(pool);
                        c = &c_cloned;
                    }
                    std::vector<T> buffer = encoder.decrypt_outputs(decryptor, *c, pool);
                    for (size_t i = li; i < ui; i++)
                        for (size_t j = lj; j < uj; j++) 
                            dec[i * output_dims + j] = buffer[(i - li) * input_block * output_block + (j - lj) * input_block + input_block - 1];
                    dj += 1;
                }
                di += 1;
            }
        } else {
            std::vector<std::vector<T>> buffer;
            for (size_t i = 0; i < outputs.data()[0].size(); i++) {
                const Ciphertext* c = &outputs[0][i];
                Ciphertext c_cloned;
                if (decryptor.on_device() && !c->on_device()) {
                    c_cloned = c->clone(pool);
                    c = &c_cloned;
                }
                buffer.push_back(encoder.decrypt_outputs(decryptor, *c, pool));
            }
            size_t li = 0; size_t di = 0; while (li < this->batch_size) {
                size_t ui = std::min(this->batch_size, li + this->batch_block);
                size_t lj = 0; size_t dj = 0; while (lj < this->output_dims) {
                    size_t uj = std::min(this->output_dims, lj + vecsize);
                    size_t cipherId = di * ceil_div(this->output_dims, this->output_block) + dj;
                    size_t packedId = cipherId / this->input_block;
                    size_t packedOffset = cipherId % this->input_block;
                    for (size_t i = li; i < ui; i++) {
                        for (size_t j = lj; j < uj; j++) {
                            dec[i * output_dims + j] = buffer[packedId][(i - li) * input_block * output_block + (j - lj) * input_block + packedOffset];
                        }
                    }
                    dj += 1;
                    lj += vecsize; 
                }
                di += 1;
                li += this->batch_block;
            }
        }
        return dec;
    }

    #define D_IMPL(adapter, dtype)                                                      \
        template std::vector<dtype> MatmulHelper::decrypt_outputs<adapter, dtype>(      \
            const adapter& encoder, const Decryptor& decryptor, const Cipher2d& outputs \
        ) const;
    D_IMPL_ALL
    #undef D_IMPL

    Cipher2d MatmulHelper::pack_outputs(const Evaluator& evaluator, const GaloisKeys& autoKey, const Cipher2d& cipher) const {
        if (!this->pack_lwe) {
            throw std::invalid_argument("[MatmulHelper::packOutputs] PackLwe not enabled");
        }
        if (cipher.data().size() == 0 || cipher.data()[0].size() == 0) {
            Cipher2d ret; ret.data().push_back(std::vector<Ciphertext>());
            return ret;
        }
        size_t packSlots = this->input_block;
        size_t totalCount = cipher.data().size() * cipher.data()[0].size();
        std::vector<Ciphertext> output; output.reserve(ceil_div(totalCount, packSlots));
        Ciphertext current; bool currentSet = false;
        size_t currentSlot = 0;

        bool is_ntt = cipher.data()[0][0].is_ntt_form();
        
        size_t field_trace_logn = 0;
        size_t field_trace_n = 1;
        while (field_trace_n != slot_count / packSlots) {
            field_trace_logn += 1;
            field_trace_n *= 2;
        }

        Ciphertext buffer = cipher.data()[0][0].clone(pool);
        Ciphertext shifted = buffer.clone(pool);
        for (size_t i = 0; i < cipher.data().size(); i++) {
            for (size_t j = 0; j < cipher.data()[0].size(); j++) {
                size_t shift = packSlots - 1;
                Ciphertext ciphertext = cipher.data()[i][j].clone(pool);
                if (is_ntt) evaluator.transform_from_ntt_inplace(ciphertext);
                if (shift != 0) {
                    evaluator.negacyclic_shift(ciphertext, 2 * slot_count - shift, buffer, pool);
                } else {
                    buffer = ciphertext.clone(pool);
                }
                
                evaluator.divide_by_poly_modulus_degree_inplace(buffer, slot_count / packSlots);
                if (is_ntt) evaluator.transform_to_ntt_inplace(buffer);
                
                evaluator.field_trace_inplace(buffer, autoKey, field_trace_logn, pool);
                if (is_ntt) evaluator.transform_from_ntt_inplace(buffer);
                
                shift = currentSlot;
                if (shift != 0) {
                    evaluator.negacyclic_shift(buffer, shift, shifted, pool);
                } else {
                    shifted = buffer.clone(pool);
                }

                if (currentSet == false) {
                    current = shifted.clone(pool);
                    currentSet = true;
                } else {
                    evaluator.add_inplace(current, shifted, pool);
                }

                currentSlot += 1;
                if (currentSlot == packSlots) {
                    currentSlot = 0; currentSet = false;
                    output.push_back(std::move(current));
                }
            }
        }
        if (currentSet) {
            output.push_back(std::move(current));
        }
        if (is_ntt) for (Ciphertext& c : output) {
            evaluator.transform_to_ntt_inplace(c);
        }
        Cipher2d ret; ret.data().push_back(output);
        return ret;
    }

    void MatmulHelper::serialize_encoded_weights(const Plain2d& w, std::ostream& stream, CompressionMode mode) const {
        size_t rows = w.data().size();
        size_t cols = w[0].size();
        if (rows == 0) throw std::invalid_argument("[MatmulHelper::serialize_encoded_weights] No rows in weight matrix.");
        if (cols == 0) throw std::invalid_argument("[MatmulHelper::serialize_encoded_weights] No columns in weight matrix.");
        for (size_t i=0; i<rows; i++) {
            if (w[i].size() != cols) throw std::invalid_argument("[MatmulHelper::serialize_encoded_weights] Weight matrix is not rectangular.");
        }
        serialize::save_object(stream, rows);
        serialize::save_object(stream, cols);
        for (size_t i = 0; i < rows; i++) {
            for (size_t j = 0; j < cols; j++) {
                w[i][j].save(stream, mode);
            }
        }
    }

    Plain2d MatmulHelper::deserialize_encoded_weights(std::istream& stream) const {
        size_t rows, cols;
        serialize::load_object(stream, rows);
        serialize::load_object(stream, cols);
        Plain2d ret; ret.data().reserve(rows);
        for (size_t i = 0; i < rows; i++) {
            std::vector<Plaintext> row; row.reserve(cols);
            for (size_t j = 0; j < cols; j++) {
                Plaintext pt;
                pt.load(stream, pool);
                row.push_back(std::move(pt));
            }
            ret.data().push_back(std::move(row));
        }
        return ret;
    }

    void MatmulHelper::serialize_outputs(const Evaluator &evaluator, const Cipher2d& x, std::ostream& stream, CompressionMode mode) const {
        HeContextPointer context = evaluator.context();
        if (!this->pack_lwe) {
            size_t vecsize = output_block;
            Plaintext pt;
            size_t di = 0;
            for (size_t li = 0; li < batch_size; li += batch_block) {
                size_t ui = (li + batch_block > batch_size) ? batch_size : (li + batch_block);
                size_t dj = 0;
                for (size_t lj = 0; lj < output_dims; lj += vecsize) {
                    size_t uj = (lj + vecsize > output_dims) ? output_dims : (lj + vecsize);
                    std::vector<size_t> required((ui - li) * (uj - lj)); size_t rid = 0;
                    for (size_t i = li; i < ui; i++)
                        for (size_t j = lj; j < uj; j++) 
                            required[rid++] = (i - li) * input_block * output_block + (j - lj) * input_block + input_block - 1;
                    x[di][dj].save_terms(stream, context, required, pool, mode);
                    dj += 1;
                }
                di += 1;
            }
        } else {
            size_t count = ceil_div(batch_size, batch_block) * ceil_div(output_dims, output_block);
            count = ceil_div(count, input_block);
            if (count != x.data()[0].size()) {
                throw std::invalid_argument("[MatmulHelper::serialize_outputs] Output ciphertext count incorrect");
            }
            for (size_t i = 0; i < x.data()[0].size(); i++) {
                x[0][i].save(stream, context, mode);
            }
        }
    }

    Cipher2d MatmulHelper::deserialize_outputs(const Evaluator &evaluator, std::istream& stream) const {
        HeContextPointer context = evaluator.context();
        if (!this->pack_lwe) {
            size_t vecsize = output_block;
            Plaintext pt;
            Cipher2d ret; ret.data().reserve(ceil_div(batch_size, batch_block));
            for (size_t li = 0; li < batch_size; li += batch_block) {
                size_t ui = (li + batch_block > batch_size) ? batch_size : (li + batch_block);
                std::vector<Ciphertext> row; row.reserve(ceil_div(output_dims, vecsize));
                for (size_t lj = 0; lj < output_dims; lj += vecsize) {
                    size_t uj = (lj + vecsize > output_dims) ? output_dims : (lj + vecsize);
                    std::vector<size_t> required((ui - li) * (uj - lj)); size_t rid = 0;
                    for (size_t i = li; i < ui; i++)
                        for (size_t j = lj; j < uj; j++) 
                            required[rid++] = (i - li) * input_block * output_block + (j - lj) * input_block + input_block - 1;
                    Ciphertext c;
                    c.load_terms(stream, context, required, pool);
                    row.push_back(std::move(c));
                }
                ret.data().push_back(std::move(row));
            }
            return ret;
        } else {
            size_t count = ceil_div(batch_size, batch_block) * ceil_div(output_dims, output_block);
            count = ceil_div(count, input_block);
            Cipher2d ret; ret.data().push_back(std::vector<Ciphertext>());
            ret[0].reserve(count);
            for (size_t i = 0; i < count; i++) {
                Ciphertext c; c.load(stream, context, pool);
                ret[0].push_back(std::move(c));
            }
            return ret;
        }
    }

    #undef D_IMPL_ALL




    // ------------------ adapters -----------------------
    
    Plain2d MatmulHelper::encode_weights_uint64s(const BatchEncoder& encoder, const uint64_t* weights) const {
        BatchEncoderAdapter adapter(encoder); Plain2d ret;
        encode_weights(adapter, nullptr, weights, false, &ret, nullptr);
        return ret;
    }
    Plain2d MatmulHelper::encode_weights_doubles(const CKKSEncoder& encoder, const double* weights, std::optional<ParmsID> parms_id, double scale) const {
        CKKSEncoderAdapter adapter(encoder, parms_id, scale); Plain2d ret;
        encode_weights(adapter, nullptr, weights, false, &ret, nullptr);
        return ret;
    }
    template <typename T>
    Plain2d MatmulHelper::encode_weights_ring2k(const PolynomialEncoderRing2k<T>& encoder, const T* weights, std::optional<ParmsID> parms_id, bool for_cipher) const {
        std::cout << "encode_weights_ring2k called by " << *this << std::endl;
        PolynomialEncoderRing2kAdapter<T> adapter(encoder, parms_id); Plain2d ret;
        encode_weights(adapter, nullptr, weights, for_cipher, &ret, nullptr);
        return ret;
    }
    template Plain2d MatmulHelper::encode_weights_ring2k<uint32_t>(
        const PolynomialEncoderRing2k<uint32_t>& encoder, const uint32_t* weights, std::optional<ParmsID> parms_id, bool for_cipher
    ) const;
    template Plain2d MatmulHelper::encode_weights_ring2k<uint64_t>(
        const PolynomialEncoderRing2k<uint64_t>& encoder, const uint64_t* weights, std::optional<ParmsID> parms_id, bool for_cipher
    ) const;
    template Plain2d MatmulHelper::encode_weights_ring2k<uint128_t>(
        const PolynomialEncoderRing2k<uint128_t>& encoder, const uint128_t* weights, std::optional<ParmsID> parms_id, bool for_cipher
    ) const;

    Plain2d MatmulHelper::encode_inputs_uint64s(const BatchEncoder& encoder, const uint64_t* inputs) const {
        BatchEncoderAdapter adapter(encoder); Plain2d ret;
        encode_inputs(adapter, nullptr, inputs, true, &ret, nullptr);
        return ret;
    }
    Plain2d MatmulHelper::encode_inputs_doubles(const CKKSEncoder& encoder, const double* inputs, std::optional<ParmsID> parms_id, double scale) const {
        CKKSEncoderAdapter adapter(encoder, parms_id, scale); Plain2d ret;
        encode_inputs(adapter, nullptr, inputs, true, &ret, nullptr);
        return ret;
    }
    template <typename T>
    Plain2d MatmulHelper::encode_inputs_ring2k(const PolynomialEncoderRing2k<T>& encoder, const T* inputs, std::optional<ParmsID> parms_id, bool for_cipher) const {
        PolynomialEncoderRing2kAdapter<T> adapter(encoder, parms_id); Plain2d ret;
        encode_inputs(adapter, nullptr, inputs, for_cipher, &ret, nullptr);
        return ret;
    }
    template Plain2d MatmulHelper::encode_inputs_ring2k<uint32_t>(
        const PolynomialEncoderRing2k<uint32_t>& encoder, const uint32_t* inputs, std::optional<ParmsID> parms_id, bool for_cipher
    ) const;
    template Plain2d MatmulHelper::encode_inputs_ring2k<uint64_t>(
        const PolynomialEncoderRing2k<uint64_t>& encoder, const uint64_t* inputs, std::optional<ParmsID> parms_id, bool for_cipher
    ) const;
    template Plain2d MatmulHelper::encode_inputs_ring2k<uint128_t>(
        const PolynomialEncoderRing2k<uint128_t>& encoder, const uint128_t* inputs, std::optional<ParmsID> parms_id, bool for_cipher
    ) const;

    Cipher2d MatmulHelper::encrypt_inputs_uint64s(const Encryptor& encryptor, const BatchEncoder& encoder, const uint64_t* inputs) const {
        BatchEncoderAdapter adapter(encoder); Cipher2d ret;
        encode_inputs(adapter, &encryptor, inputs, true, nullptr, &ret);
        return ret;
    }
    Cipher2d MatmulHelper::encrypt_inputs_doubles(const Encryptor& encryptor, const CKKSEncoder& encoder, const double* inputs, std::optional<ParmsID> parms_id, double scale) const {
        CKKSEncoderAdapter adapter(encoder, parms_id, scale); Cipher2d ret;
        encode_inputs(adapter, &encryptor, inputs, true, nullptr, &ret);
        return ret;
    }
    template <typename T>
    Cipher2d MatmulHelper::encrypt_inputs_ring2k(const Encryptor& encryptor, const PolynomialEncoderRing2k<T>& encoder, const T* inputs, std::optional<ParmsID> parms_id) const {
        PolynomialEncoderRing2kAdapter<T> adapter(encoder, parms_id); Cipher2d ret;
        encode_inputs(adapter, &encryptor, inputs, true, nullptr, &ret);
        return ret;
    }
    template Cipher2d MatmulHelper::encrypt_inputs_ring2k<uint32_t>(
        const Encryptor& encryptor, const PolynomialEncoderRing2k<uint32_t>& encoder, const uint32_t* inputs, std::optional<ParmsID> parms_id
    ) const;
    template Cipher2d MatmulHelper::encrypt_inputs_ring2k<uint64_t>(
        const Encryptor& encryptor, const PolynomialEncoderRing2k<uint64_t>& encoder, const uint64_t* inputs, std::optional<ParmsID> parms_id
    ) const;
    template Cipher2d MatmulHelper::encrypt_inputs_ring2k<uint128_t>(
        const Encryptor& encryptor, const PolynomialEncoderRing2k<uint128_t>& encoder, const uint128_t* inputs, std::optional<ParmsID> parms_id
    ) const;


    Cipher2d MatmulHelper::encrypt_weights_uint64s(const Encryptor& encryptor, const BatchEncoder& encoder, const uint64_t* weights) const {
        BatchEncoderAdapter adapter(encoder); Cipher2d ret;
        encode_weights(adapter, &encryptor, weights, true, nullptr, &ret);
        return ret;
    }
    Cipher2d MatmulHelper::encrypt_weights_doubles(const Encryptor& encryptor, const CKKSEncoder& encoder, const double* weights, std::optional<ParmsID> parms_id, double scale) const {
        CKKSEncoderAdapter adapter(encoder, parms_id, scale); Cipher2d ret;
        encode_weights(adapter, &encryptor, weights, true, nullptr, &ret);
        return ret;
    }
    template <typename T>
    Cipher2d MatmulHelper::encrypt_weights_ring2k(const Encryptor& encryptor, const PolynomialEncoderRing2k<T>& encoder, const T* inputs, std::optional<ParmsID> parms_id) const {
        PolynomialEncoderRing2kAdapter<T> adapter(encoder, parms_id); Cipher2d ret;
        encode_weights(adapter, &encryptor, inputs, true, nullptr, &ret);
        return ret;
    }
    template Cipher2d MatmulHelper::encrypt_weights_ring2k<uint32_t>(
        const Encryptor& encryptor, const PolynomialEncoderRing2k<uint32_t>& encoder, const uint32_t* weights, std::optional<ParmsID> parms_id
    ) const;
    template Cipher2d MatmulHelper::encrypt_weights_ring2k<uint64_t>(
        const Encryptor& encryptor, const PolynomialEncoderRing2k<uint64_t>& encoder, const uint64_t* weights, std::optional<ParmsID> parms_id
    ) const;
    template Cipher2d MatmulHelper::encrypt_weights_ring2k<uint128_t>(
        const Encryptor& encryptor, const PolynomialEncoderRing2k<uint128_t>& encoder, const uint128_t* weights, std::optional<ParmsID> parms_id
    ) const;

    Plain2d MatmulHelper::encode_outputs_uint64s(const BatchEncoder& encoder, const uint64_t* outputs) const {
        BatchEncoderAdapter adapter(encoder);
        return encode_outputs(adapter, outputs);
    }
    Plain2d MatmulHelper::encode_outputs_doubles(const CKKSEncoder& encoder, const double* outputs, std::optional<ParmsID> parms_id, double scale) const {
        CKKSEncoderAdapter adapter(encoder, parms_id, scale);
        return encode_outputs(adapter, outputs);
    }
    template <typename T>
    Plain2d MatmulHelper::encode_outputs_ring2k(const PolynomialEncoderRing2k<T>& encoder, const T* outputs, std::optional<ParmsID> parms_id) const {
        PolynomialEncoderRing2kAdapter<T> adapter(encoder, parms_id);
        return encode_outputs(adapter, outputs);
    }
    template Plain2d MatmulHelper::encode_outputs_ring2k<uint32_t>(
        const PolynomialEncoderRing2k<uint32_t>& encoder, const uint32_t* outputs, std::optional<ParmsID> parms_id
    ) const;
    template Plain2d MatmulHelper::encode_outputs_ring2k<uint64_t>(
        const PolynomialEncoderRing2k<uint64_t>& encoder, const uint64_t* outputs, std::optional<ParmsID> parms_id
    ) const;
    template Plain2d MatmulHelper::encode_outputs_ring2k<uint128_t>(
        const PolynomialEncoderRing2k<uint128_t>& encoder, const uint128_t* outputs, std::optional<ParmsID> parms_id
    ) const;

    std::vector<uint64_t> MatmulHelper::decrypt_outputs_uint64s(const BatchEncoder& encoder, const Decryptor& decryptor, const Cipher2d& outputs) const {
        BatchEncoderAdapter adapter(encoder);
        return decrypt_outputs<BatchEncoderAdapter, uint64_t>(adapter, decryptor, outputs);
    }
    std::vector<double> MatmulHelper::decrypt_outputs_doubles(const CKKSEncoder& encoder, const Decryptor& decryptor, const Cipher2d& outputs) const {
        CKKSEncoderAdapter adapter(encoder, std::nullopt, 0);
        return decrypt_outputs<CKKSEncoderAdapter, double>(adapter, decryptor, outputs);
    }
    template <typename T>
    std::vector<T> MatmulHelper::decrypt_outputs_ring2k(const PolynomialEncoderRing2k<T>& encoder, const Decryptor& decryptor, const Cipher2d& outputs) const {
        PolynomialEncoderRing2kAdapter<T> adapter(encoder, std::nullopt);
        return decrypt_outputs<PolynomialEncoderRing2kAdapter<T>, T>(adapter, decryptor, outputs);
    }
    template std::vector<uint32_t> MatmulHelper::decrypt_outputs_ring2k<uint32_t>(
        const PolynomialEncoderRing2k<uint32_t>& encoder, const Decryptor& decryptor, const Cipher2d& outputs
    ) const;
    template std::vector<uint64_t> MatmulHelper::decrypt_outputs_ring2k<uint64_t>(
        const PolynomialEncoderRing2k<uint64_t>& encoder, const Decryptor& decryptor, const Cipher2d& outputs
    ) const;
    template std::vector<uint128_t> MatmulHelper::decrypt_outputs_ring2k<uint128_t>(
        const PolynomialEncoderRing2k<uint128_t>& encoder, const Decryptor& decryptor, const Cipher2d& outputs
    ) const;


}}