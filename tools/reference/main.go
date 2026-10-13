// Generate deterministic behavioral vectors with the pinned reference library.
// No reference implementation source is copied into MoonErasure.
package main

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"

	"github.com/klauspost/reedsolomon"
)

type Change struct {
	Index int    `json:"index"`
	Old   string `json:"old_hex"`
	New   string `json:"new_hex"`
}

type Vector struct {
	K       int      `json:"k"`
	M       int      `json:"m"`
	Length  int      `json:"length"`
	Data    []string `json:"data_hex"`
	Encoded []string `json:"encoded_hex"`
	Missing []int    `json:"missing"`
	Targets []int    `json:"targets"`
	Selected []string `json:"selected_hex"`
	Changes []Change `json:"changes"`
	Parity  []string `json:"updated_parity_hex"`
}

func require(err error) {
	if err != nil {
		panic(err)
	}
}

func bytesFor(seed uint32, length int) []byte {
	result := make([]byte, length)
	for i := range result {
		seed = seed*1664525 + 1013904223
		result[i] = byte(seed >> 24)
	}
	return result
}

func encodedHex(shards [][]byte) []string {
	result := make([]string, len(shards))
	for i, shard := range shards {
		result[i] = hex.EncodeToString(shard)
	}
	return result
}

func clone(shards [][]byte) [][]byte {
	result := make([][]byte, len(shards))
	for i, shard := range shards {
		result[i] = append([]byte(nil), shard...)
	}
	return result
}

func main() {
	configs := [][2]int{{1, 1}, {2, 2}, {3, 2}, {4, 1}, {6, 3}, {10, 4}, {16, 8}}
	var vectors []Vector
	for _, config := range configs {
		k, m := config[0], config[1]
		for _, length := range []int{1, 3, 17, 64} {
			enc, err := reedsolomon.New(k, m, reedsolomon.WithLeopardGF(false))
			require(err)
			shards := make([][]byte, k+m)
			for i := 0; i < k; i++ {
				shards[i] = bytesFor(uint32(k*971+m*101+i*17+length), length)
			}
			for i := k; i < k+m; i++ {
				shards[i] = make([]byte, length)
			}
			require(enc.Encode(shards))
			v := Vector{K:k, M:m, Length:length, Data:encodedHex(shards[:k]), Encoded:encodedHex(shards)}
			degraded := clone(shards)
			v.Missing = []int{0}
			v.Targets = []int{0}
			if m > 1 {
				v.Missing = append(v.Missing, k+m-1)
				v.Targets = []int{k+m-1, 0}
			}
			for _, index := range v.Missing {
				degraded[index] = nil
			}
			required := make([]bool, k+m)
			for _, index := range v.Targets {
				required[index] = true
			}
			require(enc.ReconstructSome(degraded, required))
			for _, index := range v.Targets {
				if hex.EncodeToString(degraded[index]) != v.Encoded[index] {
					panic("reference selective reconstruction disagrees with encoding")
				}
				v.Selected = append(v.Selected, hex.EncodeToString(degraded[index]))
			}
			updated := clone(shards)
			newData := make([][]byte, k)
			for _, index := range []int{0, k-1} {
				if newData[index] != nil {
					continue
				}
				newData[index] = bytesFor(uint32(index*131+k*37+length*23+1), length)
				v.Changes = append(v.Changes, Change{index, v.Data[index], hex.EncodeToString(newData[index])})
			}
			require(enc.Update(updated, newData))
			// Go Update intentionally leaves data slots unchanged; persist them explicitly.
			for i, replacement := range newData {
				if replacement != nil {
					updated[i] = replacement
				}
			}
			ok, err := enc.Verify(updated)
			require(err)
			if !ok { panic(fmt.Sprintf("reference update failed: %d+%d/%d", k,m,length)) }
			v.Parity = encodedHex(updated[k:])
			vectors = append(vectors, v)
		}
	}
	output := struct {
		Reference string `json:"reference"`
		Options string `json:"options"`
		Vectors []Vector `json:"vectors"`
	}{"github.com/klauspost/reedsolomon@v1.14.2", "default Vandermonde, WithLeopardGF(false)", vectors}
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	require(encoder.Encode(output))
}
